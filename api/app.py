# app.py — SuperMart AI Complete Backend


from flask import Flask, request, jsonify, g
from flask_cors import CORS
from database import (
    db, User, Product, Stock, Staff, Order, OrderItem, Driver, Alert,
    LoginAudit, ensure_delivery_schema
)
import pickle
import numpy as np
import pandas as pd
import bcrypt
import jwt
from datetime import datetime, timedelta, timezone
from functools import wraps
import os
import math
import secrets

#  App setup
app = Flask(__name__)
CORS(app)

# SQLite database — saves as a file called supermart.db
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.abspath(os.path.join(BASE_DIR, '..', 'model'))
DATA_DIR = os.path.abspath(os.path.join(BASE_DIR, '..', 'data'))
database_url = os.getenv('DATABASE_URL', 'sqlite:///supermart.db')
if database_url.startswith('postgres://'):
    database_url = database_url.replace('postgres://', 'postgresql://', 1)
app.config['SQLALCHEMY_DATABASE_URI'] = database_url
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db.init_app(app)

JWT_SECRET = os.getenv('JWT_SECRET', 'change-this-secret-before-production')


def create_token(user):
    return jwt.encode({
        'sub': str(user.id),
        'role': user.role,
        'branch': user.branch,
        'exp': datetime.now(timezone.utc) + timedelta(hours=12),
    }, JWT_SECRET, algorithm='HS256')


def require_auth(role=None):
    """Validate a bearer token and optionally enforce a user role."""
    def decorator(function):
        @wraps(function)
        def wrapped(*args, **kwargs):
            header = request.headers.get('Authorization', '')
            if not header.startswith('Bearer '):
                return jsonify({
                    'success': False, 'message': 'Authentication required'
                }), 401
            try:
                payload = jwt.decode(
                    header[7:], JWT_SECRET, algorithms=['HS256']
                )
                user = db.session.get(User, int(payload['sub']))
            except (jwt.InvalidTokenError, KeyError, TypeError, ValueError):
                user = None
            if not user:
                return jsonify({
                    'success': False, 'message': 'Invalid or expired session'
                }), 401
            allowed_roles = (
                {role} if isinstance(role, str)
                else set(role or [])
            )
            if allowed_roles and user.role not in allowed_roles:
                return jsonify({
                    'success': False,
                    'message': f"{' or '.join(sorted(allowed_roles)).title()} access required"
                }), 403
            g.current_user = user
            return function(*args, **kwargs)
        return wrapped
    return decorator

# ── Load ML model ────────────────────────────────────────
print("Loading AI model...")
with open(os.path.join(MODEL_DIR, 'xgb_tuned.pkl'), 'rb') as f:
    model = pickle.load(f)
with open(os.path.join(MODEL_DIR, 'encoders.pkl'), 'rb') as f:
    encoders = pickle.load(f)
with open(os.path.join(MODEL_DIR, 'scaler.pkl'), 'rb') as f:
    scaler = pickle.load(f)
print("AI model loaded")

# ── Encoding maps ─────────────────────────────────────────
BRANCH_MAP   = {'A':0,'B':1,'C':2}

# Demo branch coordinates around Kandy. Replace these with your real stores.
BRANCH_LOCATIONS = {
    'A': {'name': 'Kandy City Branch', 'latitude': 7.2906, 'longitude': 80.6337},
    'B': {'name': 'Peradeniya Branch', 'latitude': 7.2631, 'longitude': 80.5967},
    'C': {'name': 'Katugastota Branch', 'latitude': 7.3334, 'longitude': 80.6215},
}


def haversine_km(lat1, lon1, lat2, lon2):
    """Distance between two GPS points in kilometres."""
    radius = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lon2 - lon1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def build_demo_route(start_lat, start_lng, end_lat, end_lng, steps=32):
    """Create a smooth demo route. Replace with Google Routes API for roads."""
    points = []
    lat_span = end_lat - start_lat
    lng_span = end_lng - start_lng
    for index in range(steps):
        t = index / (steps - 1)
        curve = math.sin(math.pi * t) * 0.0015
        points.append({
            'latitude': start_lat + lat_span * t + curve * lng_span * 8,
            'longitude': start_lng + lng_span * t - curve * lat_span * 8,
        })
    return points


def calculate_delivery_quote(branch, customer_lat, customer_lng, subtotal, slot='asap'):
    location = BRANCH_LOCATIONS[branch]
    distance = haversine_km(
        location['latitude'], location['longitude'], customer_lat, customer_lng
    )
    if subtotal >= 8000:
        fee = 0.0
        fee_reason = 'Free delivery for orders above Rs. 8,000'
    elif distance <= 3:
        fee = 250.0
        fee_reason = 'First 3 km delivery fee'
    else:
        fee = 250.0 + (distance - 3) * 60.0
        fee_reason = 'Rs. 250 for 3 km + Rs. 60 per extra km'

    discount = 100.0 if slot == '2:00 PM - 3:00 PM' and fee > 0 else 0.0
    fee = max(0.0, fee - discount)
    pending = Order.query.filter(
        Order.branch == branch,
        Order.status.in_(['pending', 'confirmed', 'preparing', 'ready'])
    ).count()
    preparation = 12 + min(pending * 3, 24)
    travel = max(6, round(distance / 22 * 60))
    return {
        'branch': branch,
        'distance_km': round(distance, 2),
        'delivery_fee': round(fee, 2),
        'slot_discount': discount,
        'fee_reason': fee_reason,
        'estimated_minutes': preparation + travel,
        'recommended_slot': '2:00 PM - 3:00 PM',
        'slot_reason': 'Lower expected branch workload and Rs. 100 delivery discount',
    }

CUSTOMER_MAP = {'Member':0,'Normal':1}
GENDER_MAP   = {'Female':0,'Male':1}
PRODUCT_MAP  = {
    'Electronic accessories':0,'Fashion accessories':1,
    'Food and beverages':2,'Health and beauty':3,
    'Home and lifestyle':4,'Sports and travel':5
}
PAYMENT_MAP  = {'Cash':0,'Credit card':1,'Ewallet':2}

def prepare_features(data):
    branch       = BRANCH_MAP.get(data.get('branch','A'),0)
    customer_type= CUSTOMER_MAP.get(data.get('customer_type','Normal'),1)
    gender       = GENDER_MAP.get(data.get('gender','Female'),0)
    product_line = PRODUCT_MAP.get(data.get('product_line','Health and beauty'),3)
    unit_price   = float(data.get('unit_price',50.0))
    quantity     = int(data.get('quantity',5))
    payment      = PAYMENT_MAP.get(data.get('payment','Ewallet'),2)
    rating       = float(data.get('rating',7.0))
    hour         = int(data.get('hour',14))
    is_weekend   = int(data.get('is_weekend',0))
    day_num      = int(data.get('day_num',2))
    month_num    = int(data.get('month_num',6))
    total        = unit_price * quantity * 1.05
    price_qty    = unit_price * quantity

    features = pd.DataFrame([[
        branch,customer_type,gender,product_line,
        unit_price,quantity,total,payment,rating,
        hour,is_weekend,day_num,month_num,price_qty
    ]],columns=[
        'Branch','Customer type','Gender','Product line',
        'Unit price','Quantity','Total','Payment','Rating',
        'hour','is_weekend','day_num','month_num','price_quantity'
    ])
    return scaler.transform(features)


# HEALTH CHECK

@app.route('/', methods=['GET'])
def home():
    return jsonify({
        'status' :'running',
        'app'    :'SuperMart AI Platform',
        'version':'2.0'
    })


# AUTH ROUTES

@app.route('/auth/login', methods=['POST'])
def login():
    """Login for both managers and customers"""
    data  = request.get_json(silent=True) or {}
    email = data.get('email','').lower().strip()
    pwd   = data.get('password','')
    requested_role = data.get('role')

    user = User.query.filter_by(email=email).first()
    if not user:
        db.session.add(LoginAudit(
            email=email or '(empty)', success=False,
            ip_address=request.headers.get('X-Forwarded-For', request.remote_addr)
        ))
        db.session.commit()
        return jsonify({'success':False,'message':'Email not found'}), 401

    if not bcrypt.checkpw(pwd.encode(), user.password.encode()):
        db.session.add(LoginAudit(
            user_id=user.id, email=email, role=user.role, branch=user.branch,
            success=False,
            ip_address=request.headers.get('X-Forwarded-For', request.remote_addr)
        ))
        db.session.commit()
        return jsonify({'success':False,'message':'Wrong password'}), 401
    if requested_role and user.role != requested_role:
        return jsonify({
            'success':False,
            'message':f"This account is registered as {user.role}, not {requested_role}"
        }), 403

    db.session.add(LoginAudit(
        user_id=user.id, email=email, role=user.role, branch=user.branch,
        success=True,
        ip_address=request.headers.get('X-Forwarded-For', request.remote_addr)
    ))
    db.session.commit()
    return jsonify({
        'success':True, 'user':user.to_dict(), 'token':create_token(user)
    })

@app.route('/auth/register', methods=['POST'])
def register():
    """Register a new customer account"""
    data = request.get_json(silent=True) or {}
    if any(not str(data.get(field, '')).strip()
           for field in ['name', 'email', 'password']):
        return jsonify({
            'success':False, 'message':'Name, email and password are required'
        }), 400
    if User.query.filter_by(email=data['email'].lower()).first():
        return jsonify({'success':False,'message':'Email already registered'}), 400

    hashed = bcrypt.hashpw(data['password'].encode(), bcrypt.gensalt()).decode()
    user   = User(
        name    = data['name'],
        email   = data['email'].lower().strip(),
        password= hashed,
        role    = 'customer',
        phone   = data.get('phone',''),
        address = data.get('address',''),
    )
    db.session.add(user)
    db.session.commit()
    return jsonify({
        'success':True, 'user':user.to_dict(), 'token':create_token(user)
    })


# AI PREDICTION ROUTES (existing — kept + improved)

@app.route('/predict', methods=['POST'])
def predict():
    """XGBoost gross income prediction"""
    try:
        data       = request.get_json()
        features   = prepare_features(data)
        prediction = float(model.predict(features)[0])
        return jsonify({
            'success'               :True,
            'predicted_gross_income':round(prediction,2),
            'currency'              :'USD',
        })
    except Exception as e:
        return jsonify({'success':False,'error':str(e)}),400


@app.route('/manager/forecast', methods=['POST'])
@require_auth('manager')
def manager_forecast():
    """Predict transaction gross income and derive net after entered costs."""
    try:
        data = request.get_json(silent=True) or {}
        operating_cost = float(data.get('operating_cost', 0))
        if operating_cost < 0:
            return jsonify({
                'success': False, 'message': 'Operating cost cannot be negative'
            }), 400
        unit_price = float(data.get('unit_price', 0))
        quantity = int(data.get('quantity', 0))
        if unit_price <= 0 or quantity <= 0:
            return jsonify({
                'success': False,
                'message': 'Unit price and quantity must be greater than zero'
            }), 400
        features = prepare_features(data)
        gross_income = max(0.0, float(model.predict(features)[0]))
        estimated_net = gross_income - operating_cost
        sales_total = unit_price * quantity * 1.05
        return jsonify({
            'success': True,
            'predicted_gross_income': round(gross_income, 2),
            'operating_cost': round(operating_cost, 2),
            'estimated_net_income': round(estimated_net, 2),
            'estimated_sales_total': round(sales_total, 2),
            'currency': 'USD',
            'explanation': (
                'XGBoost predicts gross income from transaction features. '
                'Estimated net income equals predicted gross income minus the '
                'operating cost entered by the manager.'
            ),
        })
    except (TypeError, ValueError) as error:
        return jsonify({'success': False, 'message': str(error)}), 400

@app.route('/history', methods=['GET'])
def get_history():
    """Sample historical actual vs predicted data"""
    history = [
        {'date':'2019-03-01','branch':'A','product_line':'Health and beauty',
         'actual':35.57,'predicted':34.20},
        {'date':'2019-03-02','branch':'B','product_line':'Food and beverages',
         'actual':87.32,'predicted':89.10},
        {'date':'2019-03-03','branch':'C','product_line':'Fashion accessories',
         'actual':62.14,'predicted':60.80},
        {'date':'2019-03-04','branch':'A','product_line':'Sports and travel',
         'actual':124.50,'predicted':121.30},
        {'date':'2019-03-05','branch':'B','product_line':'Electronic accessories',
         'actual':45.20,'predicted':47.60},
        {'date':'2019-03-06','branch':'C','product_line':'Home and lifestyle',
         'actual':98.75,'predicted':95.40},
        {'date':'2019-03-07','branch':'A','product_line':'Health and beauty',
         'actual':156.30,'predicted':158.90},
    ]
    return jsonify({'history':history})


# MANAGER ROUTES — STOCK

@app.route('/manager/stock/<branch>', methods=['GET'])
@require_auth(('manager', 'staff'))
def get_stock(branch):
    """Get all stock for a specific branch"""
    stocks = Stock.query.filter_by(branch=branch.upper()).all()
    return jsonify({
        'success':True,
        'branch' :branch.upper(),
        'stock'  :[s.to_dict() for s in stocks],
        'low_count': sum(1 for s in stocks if s.quantity <= s.min_quantity)
    })

@app.route('/manager/stock/update', methods=['POST'])
@require_auth('manager')
def update_stock():
    """Update stock quantity — manager restocks a product"""
    data       = request.get_json()
    product_id = data.get('product_id')
    branch     = data.get('branch','').upper()
    new_qty    = int(data.get('quantity',0))

    stock = Stock.query.filter_by(
        product_id=product_id, branch=branch
    ).first()

    if not stock:
        return jsonify({'success':False,'message':'Stock entry not found'}),404

    stock.quantity    = new_qty
    stock.last_updated= datetime.utcnow()
    db.session.commit()

    # Auto-generate alert if stock is still low
    if stock.quantity <= stock.min_quantity:
        alert = Alert(
            branch=branch,
            type='low_stock',
            message=f"{stock.product.name} is still low — only {stock.quantity} units at Branch {branch}"
        )
        db.session.add(alert)
        db.session.commit()

    return jsonify({'success':True,'stock':stock.to_dict()})


# MANAGER ROUTES — STAFF

@app.route('/manager/staff/<branch>', methods=['GET'])
@require_auth('manager')
def get_staff(branch):
    """Get all staff for a branch"""
    staff = Staff.query.filter_by(
        branch=branch.upper(), is_active=True
    ).all()
    return jsonify({
        'success':True,
        'branch' :branch.upper(),
        'staff'  :[s.to_dict() for s in staff],
        'count'  :len(staff)
    })

@app.route('/manager/staff/add', methods=['POST'])
@require_auth('manager')
def add_staff():
    """Add a new staff member"""
    data = request.get_json()
    staff = Staff(
        name       = data['name'],
        role       = data['role'],
        branch     = data['branch'].upper(),
        phone      = data.get('phone',''),
        shift      = data['shift'],
        shift_start= data['shift_start'],
        shift_end  = data['shift_end'],
    )
    db.session.add(staff)
    db.session.commit()
    return jsonify({'success':True,'staff':staff.to_dict()})

@app.route('/manager/staff/update', methods=['POST'])
@require_auth('manager')
def update_staff():
    """Update staff shift or status"""
    data     = request.get_json()
    staff_id = data.get('staff_id')
    staff    = Staff.query.get(staff_id)

    if not staff:
        return jsonify({'success':False,'message':'Staff not found'}),404

    if 'shift'       in data: staff.shift       = data['shift']
    if 'shift_start' in data: staff.shift_start = data['shift_start']
    if 'shift_end'   in data: staff.shift_end   = data['shift_end']
    if 'is_active'   in data: staff.is_active   = data['is_active']
    if 'role'        in data: staff.role        = data['role']

    db.session.commit()
    return jsonify({'success':True,'staff':staff.to_dict()})


# MANAGER ROUTES — ALERTS

@app.route('/manager/alerts/<branch>', methods=['GET'])
@require_auth(('manager', 'staff'))
def get_alerts(branch):
    """Get unread alerts for a branch"""
    alerts = Alert.query.filter_by(
        branch=branch.upper(), is_read=False
    ).order_by(Alert.created_at.desc()).all()
    return jsonify({
        'success':True,
        'alerts' :[a.to_dict() for a in alerts],
        'count'  :len(alerts)
    })

@app.route('/manager/alerts/read', methods=['POST'])
@require_auth(('manager', 'staff'))
def mark_alert_read():
    """Mark an alert as read"""
    data     = request.get_json()
    alert_id = data.get('alert_id')
    alert    = Alert.query.get(alert_id)
    if alert:
        alert.is_read = True
        db.session.commit()
    return jsonify({'success':True})

# CUSTOMER ROUTES — PRODUCTS

@app.route('/products', methods=['GET'])
def get_products():
    """Get all available products — optionally filter by category"""
    category = request.args.get('category','')
    branch   = request.args.get('branch','A').upper()

    if category:
        products = Product.query.filter_by(
            category=category, is_available=True
        ).all()
    else:
        products = Product.query.filter_by(is_available=True).all()

    result = []
    for p in products:
        prod_dict = p.to_dict()
        # Add stock info for the requested branch
        stock = Stock.query.filter_by(
            product_id=p.id, branch=branch
        ).first()
        prod_dict['stock_qty']   = stock.quantity if stock else 0
        prod_dict['in_stock']    = (stock.quantity > 0) if stock else False
        result.append(prod_dict)

    categories = db.session.query(Product.category).distinct().all()
    return jsonify({
        'success'   :True,
        'products'  :result,
        'categories':[c[0] for c in categories],
        'count'     :len(result)
    })

@app.route('/products/<int:product_id>', methods=['GET'])
def get_product(product_id):
    """Get single product with stock across all branches"""
    product = Product.query.get(product_id)
    if not product:
        return jsonify({'success':False,'message':'Product not found'}),404

    prod_dict = product.to_dict()
    prod_dict['stock_by_branch'] = {}
    for branch in ['A','B','C']:
        stock = Stock.query.filter_by(
            product_id=product_id, branch=branch
        ).first()
        prod_dict['stock_by_branch'][branch] = stock.quantity if stock else 0

    return jsonify({'success':True,'product':prod_dict})


# CUSTOMER ROUTES — SMART DELIVERY AND ORDERS

@app.route('/delivery/branches', methods=['GET'])
@require_auth(('customer', 'manager', 'staff'))
def delivery_branches():
    return jsonify({'success': True, 'branches': BRANCH_LOCATIONS})


@app.route('/delivery/recommend-branch', methods=['POST'])
@require_auth('customer')
def recommend_delivery_branch():
    data = request.get_json() or {}
    try:
        customer_lat = float(data['latitude'])
        customer_lng = float(data['longitude'])
    except (KeyError, TypeError, ValueError):
        return jsonify({'success': False, 'message': 'Valid GPS location is required'}), 400

    items = data.get('items', [])
    if not items:
        return jsonify({'success': False, 'message': 'Cart is empty'}), 400

    results = []
    for branch, location in BRANCH_LOCATIONS.items():
        missing = []
        for item in items:
            try:
                product_id = int(item.get('product_id'))
                quantity = int(item.get('quantity', 0))
            except (TypeError, ValueError):
                missing.append('Invalid cart item')
                continue
            stock = Stock.query.filter_by(product_id=product_id, branch=branch).first()
            if not stock or stock.quantity < quantity:
                product = db.session.get(Product, product_id)
                missing.append(product.name if product else f'Product {product_id}')

        distance = haversine_km(
            location['latitude'], location['longitude'], customer_lat, customer_lng
        )
        pending = Order.query.filter(
            Order.branch == branch,
            Order.status.in_(['pending', 'confirmed', 'preparing', 'ready'])
        ).count()
        preparation = 12 + min(pending * 3, 24)
        travel = max(6, round(distance / 22 * 60))
        all_available = not missing
        score = distance * 2 + pending * 3 + (0 if all_available else 1000 + len(missing) * 100)
        results.append({
            'branch': branch,
            'branch_name': location['name'],
            'distance_km': round(distance, 2),
            'pending_orders': pending,
            'all_items_available': all_available,
            'missing_items': missing,
            'estimated_minutes': preparation + travel,
            'score': round(score, 2),
        })

    available = [result for result in results if result['all_items_available']]
    recommended = min(available or results, key=lambda item: item['score'])
    recommended['reason'] = (
        'All cart items are available with the best balance of distance and branch workload.'
        if recommended['all_items_available']
        else 'No branch has every item; this branch has the best available combination.'
    )
    return jsonify({
        'success': True,
        'recommended': recommended,
        'branches': sorted(results, key=lambda item: item['score']),
    })


@app.route('/delivery/calculate', methods=['POST'])
@require_auth('customer')
def calculate_delivery():
    data = request.get_json() or {}
    branch = str(data.get('branch', 'A')).upper()
    if branch not in BRANCH_LOCATIONS:
        return jsonify({'success': False, 'message': 'Invalid branch'}), 400
    try:
        latitude = float(data['latitude'])
        longitude = float(data['longitude'])
        subtotal = float(data.get('subtotal', 0))
    except (KeyError, TypeError, ValueError):
        return jsonify({'success': False, 'message': 'Invalid delivery calculation data'}), 400
    quote = calculate_delivery_quote(
        branch, latitude, longitude, subtotal, str(data.get('delivery_slot', 'asap'))
    )
    return jsonify({'success': True, 'quote': quote})


@app.route('/orders/place', methods=['POST'])
@require_auth('customer')
def place_order():
    """Place a pickup order or a GPS-enabled doorstep delivery order."""
    data = request.get_json() or {}
    customer_id = data.get('customer_id')
    branch = str(data.get('branch', 'A')).upper()
    order_type = data.get('order_type', 'pickup')
    items_data = data.get('items', [])

    if not items_data:
        return jsonify({'success': False, 'message': 'No items in order'}), 400
    if branch not in BRANCH_MAP:
        return jsonify({'success': False, 'message': 'Invalid branch'}), 400
    if order_type not in ['pickup', 'delivery']:
        return jsonify({'success': False, 'message': 'Invalid order type'}), 400
    if not db.session.get(User, customer_id):
        return jsonify({'success': False, 'message': 'Customer not found'}), 404
    if g.current_user.id != customer_id:
        return jsonify({'success': False, 'message': 'Cannot order for another customer'}), 403

    delivery_lat = delivery_lng = None
    if order_type == 'delivery':
        if not str(data.get('delivery_address', '')).strip():
            return jsonify({'success': False, 'message': 'Delivery address is required'}), 400
        try:
            delivery_lat = float(data['delivery_latitude'])
            delivery_lng = float(data['delivery_longitude'])
        except (KeyError, TypeError, ValueError):
            return jsonify({
                'success': False,
                'message': 'Select the doorstep location on the GPS map'
            }), 400

    validated = []
    subtotal = 0.0
    for item in items_data:
        product = db.session.get(Product, item.get('product_id'))
        try:
            qty = int(item.get('quantity', 0))
        except (TypeError, ValueError):
            qty = 0
        if not product or qty <= 0:
            return jsonify({'success': False, 'message': 'Invalid product or quantity'}), 400
        stock = Stock.query.filter_by(product_id=product.id, branch=branch).first()
        if not stock or stock.quantity < qty:
            available = stock.quantity if stock else 0
            return jsonify({
                'success': False,
                'message': f'Only {available} unit(s) of {product.name} are available at Branch {branch}'
            }), 409
        subtotal += product.price * qty
        validated.append((product, stock, qty))

    quote = {
        'distance_km': 0.0,
        'delivery_fee': 0.0,
        'estimated_minutes': 0,
    }
    if order_type == 'delivery':
        quote = calculate_delivery_quote(
            branch,
            delivery_lat,
            delivery_lng,
            subtotal,
            str(data.get('delivery_slot', 'asap')),
        )

    order = Order(
        customer_id=customer_id,
        branch=branch,
        order_type=order_type,
        status='pending',
        delivery_address=data.get('delivery_address', ''),
        delivery_latitude=delivery_lat,
        delivery_longitude=delivery_lng,
        delivery_landmark=data.get('delivery_landmark', ''),
        delivery_instructions=data.get('delivery_instructions', ''),
        contactless_delivery=bool(data.get('contactless_delivery', False)),
        delivery_fee=quote['delivery_fee'],
        delivery_distance=quote['distance_km'],
        delivery_slot=data.get('delivery_slot', 'asap'),
        estimated_delivery_minutes=quote['estimated_minutes'],
        notes=data.get('notes', ''),
    )
    db.session.add(order)
    db.session.flush()

    for product, stock, qty in validated:
        db.session.add(OrderItem(
            order_id=order.id,
            product_id=product.id,
            quantity=qty,
            unit_price=product.price,
        ))
        stock.quantity -= qty
        stock.last_updated = datetime.utcnow()
        if stock.quantity <= stock.min_quantity:
            db.session.add(Alert(
                branch=branch,
                type='low_stock',
                message=f'{product.name} is running low - only {stock.quantity} units left at Branch {branch}'
            ))

    order.total_amount = round(subtotal * 1.05 + quote['delivery_fee'], 2)
    db.session.commit()
    return jsonify({
        'success': True,
        'order': order.to_dict(),
        'message': f'Order #{order.id} placed successfully!'
    })


@app.route('/orders/customer/<int:customer_id>', methods=['GET'])
@require_auth('customer')
def get_customer_orders(customer_id):
    if g.current_user.id != customer_id:
        return jsonify({'success': False, 'message': 'Access denied'}), 403
    orders = Order.query.filter_by(customer_id=customer_id).order_by(Order.created_at.desc()).all()
    return jsonify({'success': True, 'orders': [order.to_dict() for order in orders]})


def assign_available_driver(order):
    driver = Driver.query.filter_by(
        branch=order.branch, availability_status='available'
    ).first()
    if not driver:
        driver = Driver.query.filter_by(branch=order.branch).first()
    if not driver:
        return None
    order.driver_id = driver.id
    order.delivery_pin = order.delivery_pin or str(secrets.randbelow(9000) + 1000)
    driver.availability_status = 'assigned'
    location = BRANCH_LOCATIONS[order.branch]
    driver.current_latitude = location['latitude']
    driver.current_longitude = location['longitude']
    driver.last_location_update = datetime.utcnow()
    return driver


@app.route('/orders/assign-driver', methods=['POST'])
@require_auth(('manager', 'staff'))
def assign_driver():
    data = request.get_json() or {}
    order = db.session.get(Order, data.get('order_id'))
    if not order:
        return jsonify({'success': False, 'message': 'Order not found'}), 404
    if g.current_user.branch != order.branch:
        return jsonify({'success': False, 'message': 'Access denied'}), 403
    if order.order_type != 'delivery':
        return jsonify({'success': False, 'message': 'Pickup orders do not use a rider'}), 400
    driver = None
    if data.get('driver_id'):
        driver = db.session.get(Driver, data['driver_id'])
        if driver and driver.branch != order.branch:
            return jsonify({'success': False, 'message': 'Driver belongs to another branch'}), 400
        if driver:
            order.driver_id = driver.id
            order.delivery_pin = order.delivery_pin or str(secrets.randbelow(9000) + 1000)
            driver.availability_status = 'assigned'
    else:
        driver = assign_available_driver(order)
    if not driver:
        return jsonify({'success': False, 'message': 'No delivery driver is available'}), 409
    order.status = 'rider_assigned'
    order.updated_at = datetime.utcnow()
    db.session.commit()
    return jsonify({'success': True, 'order': order.to_dict(include_pin=False)})


@app.route('/orders/update-status', methods=['POST'])
@require_auth(('manager', 'staff'))
def update_order_status():
    data = request.get_json() or {}
    order = db.session.get(Order, data.get('order_id'))
    status = data.get('status')
    allowed = {
        'pending', 'confirmed', 'preparing', 'ready', 'rider_assigned',
        'out_for_delivery', 'rider_nearby', 'delivered', 'cancelled'
    }
    if status not in allowed:
        return jsonify({'success': False, 'message': 'Invalid order status'}), 400
    if not order:
        return jsonify({'success': False, 'message': 'Order not found'}), 404
    if g.current_user.branch != order.branch:
        return jsonify({'success': False, 'message': 'Access denied'}), 403
    if order.order_type == 'pickup' and status in {'rider_assigned', 'out_for_delivery', 'rider_nearby'}:
        return jsonify({'success': False, 'message': 'Pickup orders do not use a rider'}), 400
    if status == 'delivered' and order.order_type == 'delivery' and order.delivery_pin:
        return jsonify({
            'success': False,
            'message': 'Enter the customer delivery PIN to complete this order'
        }), 409

    if status in {'rider_assigned', 'out_for_delivery', 'rider_nearby'} and not order.driver_id:
        if not assign_available_driver(order):
            return jsonify({'success': False, 'message': 'No delivery driver is available'}), 409
    if order.driver:
        order.driver.availability_status = (
            'delivering' if status in {'out_for_delivery', 'rider_nearby'} else 'assigned'
        )
    if status == 'cancelled' and order.driver:
        order.driver.availability_status = 'available'

    order.status = status
    order.updated_at = datetime.utcnow()
    db.session.commit()
    return jsonify({'success': True, 'order': order.to_dict(include_pin=False)})


@app.route('/orders/<int:order_id>/tracking', methods=['GET'])
@require_auth(('customer', 'manager', 'staff'))
def get_order_tracking(order_id):
    order = db.session.get(Order, order_id)
    if not order:
        return jsonify({'success': False, 'message': 'Order not found'}), 404
    if g.current_user.role == 'customer' and order.customer_id != g.current_user.id:
        return jsonify({'success': False, 'message': 'Access denied'}), 403
    if g.current_user.role in {'manager', 'staff'} and g.current_user.branch != order.branch:
        return jsonify({'success': False, 'message': 'Access denied'}), 403

    branch_location = BRANCH_LOCATIONS[order.branch]
    customer_location = {
        'latitude': order.delivery_latitude or branch_location['latitude'],
        'longitude': order.delivery_longitude or branch_location['longitude'],
    }
    route = build_demo_route(
        branch_location['latitude'], branch_location['longitude'],
        customer_location['latitude'], customer_location['longitude']
    ) if order.order_type == 'delivery' else []

    progress = 0
    if route:
        if order.status == 'delivered':
            progress = len(route) - 1
        elif order.status == 'rider_nearby':
            progress = max(int(len(route) * .82), 1)
        elif order.status == 'out_for_delivery':
            elapsed = max(0, (datetime.utcnow() - order.updated_at).total_seconds())
            progress = min(int(elapsed // 4), len(route) - 2)

    rider_location = route[progress] if route else branch_location
    remaining_distance = haversine_km(
        rider_location['latitude'], rider_location['longitude'],
        customer_location['latitude'], customer_location['longitude']
    ) if route else 0.0
    nearby = bool(route and remaining_distance <= .30)
    effective_status = 'rider_nearby' if order.status == 'out_for_delivery' and nearby else order.status
    eta = 0 if order.status == 'delivered' else max(1, math.ceil(remaining_distance / 18 * 60))

    driver_data = order.driver.to_dict() if order.driver else None
    if driver_data:
        driver_data['current_latitude'] = rider_location['latitude']
        driver_data['current_longitude'] = rider_location['longitude']

    include_pin = g.current_user.role == 'customer'
    return jsonify({
        'success': True,
        'order': order.to_dict(include_pin=include_pin),
        'effective_status': effective_status,
        'branch_location': {**branch_location, 'branch': order.branch},
        'customer_location': customer_location,
        'driver': driver_data,
        'route_points': route,
        'completed_route': route[:progress + 1] if route else [],
        'remaining_route': route[progress:] if route else [],
        'remaining_distance_km': round(remaining_distance, 2),
        'estimated_arrival_minutes': eta,
        'nearby': nearby,
        'route_mode': 'demo_simulation',
    })


@app.route('/orders/verify-delivery-pin', methods=['POST'])
@require_auth(('manager', 'staff'))
def verify_delivery_pin():
    data = request.get_json() or {}
    order = db.session.get(Order, data.get('order_id'))
    if not order:
        return jsonify({'success': False, 'message': 'Order not found'}), 404
    if g.current_user.branch != order.branch:
        return jsonify({'success': False, 'message': 'Access denied'}), 403
    if order.order_type != 'delivery':
        return jsonify({'success': False, 'message': 'Pickup orders do not use a delivery PIN'}), 400
    if not order.delivery_pin or str(data.get('pin', '')).strip() != order.delivery_pin:
        return jsonify({'success': False, 'message': 'Incorrect delivery PIN'}), 400
    order.status = 'delivered'
    order.delivered_at = datetime.utcnow()
    order.updated_at = datetime.utcnow()
    if order.driver:
        order.driver.availability_status = 'available'
        order.driver.current_latitude = order.delivery_latitude
        order.driver.current_longitude = order.delivery_longitude
        order.driver.last_location_update = datetime.utcnow()
    db.session.commit()
    return jsonify({'success': True, 'order': order.to_dict(include_pin=False)})


@app.route('/drivers/update-location', methods=['POST'])
@require_auth(('manager', 'staff'))
def update_driver_location():
    data = request.get_json() or {}
    driver = db.session.get(Driver, data.get('driver_id'))
    if not driver:
        return jsonify({'success': False, 'message': 'Driver not found'}), 404
    if g.current_user.branch != driver.branch:
        return jsonify({'success': False, 'message': 'Access denied'}), 403
    try:
        driver.current_latitude = float(data['latitude'])
        driver.current_longitude = float(data['longitude'])
    except (KeyError, TypeError, ValueError):
        return jsonify({'success': False, 'message': 'Invalid GPS coordinates'}), 400
    driver.last_location_update = datetime.utcnow()
    db.session.commit()
    return jsonify({'success': True, 'driver': driver.to_dict()})


@app.route('/orders/branch/<branch>', methods=['GET'])
@require_auth(('manager', 'staff'))
def get_branch_orders(branch):
    branch = branch.upper()
    if g.current_user.branch != branch:
        return jsonify({'success': False, 'message': 'Access denied'}), 403
    status = request.args.get('status', '')
    query = Order.query.filter_by(branch=branch)
    if status:
        query = query.filter_by(status=status)
    orders = query.order_by(Order.created_at.desc()).all()
    return jsonify({
        'success': True,
        'orders': [order.to_dict(include_pin=False) for order in orders],
        'count': len(orders),
    })


@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy'}), 200


@app.route('/manager/insights/<branch>', methods=['GET'])
@require_auth('manager')
def manager_insights(branch):
    """Data-backed category, rush-hour, inventory and staffing guidance."""
    branch = branch.upper()
    if branch not in BRANCH_MAP:
        return jsonify({'success': False, 'message': 'Invalid branch'}), 400

    sales = pd.read_csv(os.path.join(DATA_DIR, 'supermarket_sales_cleaned.csv'))
    branch_sales = sales[sales['Branch'] == branch]
    categories = (
        branch_sales.groupby('Product line')['gross income']
        .agg(['sum', 'mean', 'count']).sort_values('sum', ascending=False)
    )
    hourly = branch_sales.groupby('hour').size().sort_values(ascending=False).head(3)
    rush_hours = []
    for hour, count in hourly.items():
        label = datetime.strptime(str(int(hour)), '%H').strftime('%I %p').lstrip('0')
        rush_hours.append({
            'hour': int(hour),
            'label': label,
            'transactions': int(count),
            'recommended_cashiers': max(
                2, int(np.ceil(count / max(float(hourly.mean()), 1) * 2))
            ),
        })

    low_stock = Stock.query.filter(
        Stock.branch == branch, Stock.quantity <= Stock.min_quantity
    ).count()
    active_staff = Staff.query.filter_by(branch=branch, is_active=True).count()
    pending_orders = Order.query.filter(
        Order.branch == branch,
        Order.status.in_(['pending', 'confirmed', 'preparing'])
    ).count()
    top_category = categories.index[0] if len(categories) else None

    return jsonify({
        'success': True,
        'branch': branch,
        'kpis': {
            'historical_income': round(float(branch_sales['gross income'].sum()), 2),
            'transactions': int(len(branch_sales)),
            'average_basket_quantity': round(float(branch_sales['Quantity'].mean()), 2),
            'average_rating': round(float(branch_sales['Rating'].mean()), 2),
            'active_staff': active_staff,
            'pending_orders': pending_orders,
            'low_stock_items': low_stock,
            'model_r2': 0.9937,
        },
        'categories': [{
            'name': name,
            'income': round(float(row['sum']), 2),
            'average_income': round(float(row['mean']), 2),
            'transactions': int(row['count']),
        } for name, row in categories.iterrows()],
        'rush_hours': rush_hours,
        'recommendations': [
            f"Schedule extra cashiers around {rush_hours[0]['label']}."
            if rush_hours else 'No rush-hour data available.',
            f"Prioritize {top_category} inventory and promotions."
            if top_category else 'No category data available.',
            f"Restock {low_stock} item(s) at or below safety level."
            if low_stock else 'All inventory is above its safety level.',
        ],
    })


@app.route('/manager/login-activity', methods=['GET'])
@require_auth('manager')
def login_activity():
    """Recent authentication audit rows for a manager demonstration."""
    limit = min(max(request.args.get('limit', 30, type=int), 1), 100)
    events = LoginAudit.query.order_by(
        LoginAudit.created_at.desc()
    ).limit(limit).all()
    return jsonify({
        'success': True,
        'events': [event.to_dict() for event in events],
        'note': (
            'These are authentication attempts, not guaranteed active sessions. '
            'JWTs expire after 12 hours and are not stored in this table.'
        ),
    })


@app.route('/customer/offers/<int:customer_id>', methods=['GET'])
@require_auth('customer')
def customer_offers(customer_id):
    """Explainable offers based on the customer's previous order categories."""
    user = db.session.get(User, customer_id)
    if not user:
        return jsonify({'success': False, 'message': 'Customer not found'}), 404
    if g.current_user.id != customer_id:
        return jsonify({'success': False, 'message': 'Access denied'}), 403
    category_spend = {}
    for order in Order.query.filter_by(customer_id=customer_id).all():
        for item in order.items:
            category = item.product.category
            category_spend[category] = (
                category_spend.get(category, 0) + item.quantity * item.unit_price
            )
    preferred = (
        max(category_spend, key=category_spend.get)
        if category_spend else 'Food and beverages'
    )
    products = Product.query.filter_by(
        category=preferred, is_available=True
    ).limit(4).all()
    return jsonify({
        'success': True,
        'preferred_category': preferred,
        'offers': [{
            **product.to_dict(),
            'discount_percent': 10,
            'offer_price': round(product.price * .9, 2),
            'reason': f'Recommended from your interest in {preferred}',
        } for product in products],
    })


@app.route('/assistant', methods=['POST'])
def shopping_assistant():
    """Answer supermarket-domain questions using live catalog and stock data."""
    data = request.get_json(silent=True) or {}
    message = str(data.get('message', '')).strip().lower()
    branch = str(data.get('branch', 'A')).upper()
    if branch not in BRANCH_MAP:
        branch = 'A'
    products = Product.query.filter_by(is_available=True).all()
    stop_words = {
        'the', 'and', 'for', 'with', 'have', 'what', 'where', 'which',
        'show', 'find', 'want', 'need', 'your', 'there', 'please', 'about',
        'does', 'this', 'that', 'from', 'item', 'items', 'product', 'products',
    }
    terms = [
        ''.join(char for char in term if char.isalnum())
        for term in message.split()
    ]
    terms = [term for term in terms if len(term) > 2 and term not in stop_words]
    matches = [
        product for product in products
        if any(term in (
            product.name + ' ' + product.category + ' ' + (product.description or '')
        ).lower() for term in terms)
    ][:4]

    categories = sorted({product.category for product in products})
    cheapest = sorted(products, key=lambda product: product.price)[:4]
    expensive = sorted(products, key=lambda product: product.price, reverse=True)[:4]
    answer_products = matches

    if not message:
        answer = 'Please type a question about products, prices, stock, offers, orders, or delivery.'
    elif any(word in message for word in ['hello', 'hi ', 'hey', 'good morning', 'good evening']):
        answer = (
            'Hello! I am the SuperMart shopping assistant. I can search the live '
            'catalog, check branch stock and prices, explain offers, and help '
            'with checkout, delivery, and order tracking.'
        )
    elif any(phrase in message for phrase in ['who are you', 'what can you do', 'help me']):
        answer = (
            'I can: find products by name or category; show prices and branch '
            'availability; suggest cheaper items; explain the 10% personalized '
            'offers; and guide you through cart, checkout, delivery, and tracking.'
        )
    elif any(word in message for word in ['category', 'categories', 'departments']):
        answer = 'Our product categories are: ' + ', '.join(categories) + '.'
    elif any(word in message for word in ['branch', 'branches', 'location', 'locations']):
        answer = (
            'SuperMart has Branch A, Branch B, and Branch C. Select a branch at '
            'the top of Shop; prices share one catalog while stock is maintained '
            'separately for each branch.'
        )
    elif any(word in message for word in ['cheapest', 'cheap', 'budget', 'lowest price']):
        answer_products = cheapest
        answer = 'The lowest-priced available products are: ' + ', '.join(
            f'{product.name} (Rs. {product.price:.2f})' for product in cheapest
        ) + '.'
    elif any(word in message for word in ['expensive', 'highest price']):
        answer_products = expensive
        answer = 'The highest-priced catalog products are: ' + ', '.join(
            f'{product.name} (Rs. {product.price:.2f})' for product in expensive
        ) + '.'
    elif any(word in message for word in ['offer', 'offers', 'discount', 'sale']):
        answer = (
            'Open AI Offers to see a 10% personalized discount. The recommended '
            'category comes from your previous order items; a new customer starts '
            'with Food and beverages until purchase history exists.'
        )
    elif any(word in message for word in ['pay', 'payment', 'cash', 'card']):
        answer = (
            'This project records checkout and order totals, but no real payment '
            'gateway is connected. For the viva, place the order as delivery or '
            'pickup and explain that Stripe or another provider is a future integration.'
        )
    elif any(word in message for word in ['track', 'delivery', 'order', 'shipping']):
        answer = (
            'Open My Orders to see every purchase. A manager changes its status '
            'through pending, confirmed, preparing, ready, out for delivery, and '
            'delivered. Pull down on My Orders to refresh.'
        )
    elif any(word in message for word in ['cart', 'checkout', 'buy', 'purchase']):
        answer = (
            'Add an in-stock product from Shop, open Cart, adjust quantities, '
            'choose delivery or pickup, select the GPS doorstep location, then '
            'Place order. The server validates stock before saving the order.'
        )
    elif any(word in message for word in ['stock', 'available', 'availability']) and matches:
        answer = 'Here is the live availability for your selected branch.'
    elif any(word in message for word in ['price', 'cost', 'much']) and matches:
        answer = 'Current prices: ' + ', '.join(
            f'{product.name} costs Rs. {product.price:.2f}' for product in matches
        ) + '.'
    elif matches:
        answer = 'I found these catalog matches: ' + ', '.join(
            f'{product.name} (Rs. {product.price:.2f})' for product in matches
        ) + '. Select + to add one to your cart.'
    else:
        answer = (
            'I could not match that to SuperMart data. Ask me about a product '
            'name, category, price, stock, cheapest items, offers, branches, '
            'cart, checkout, delivery, or order tracking.'
        )
    results = []
    for product in answer_products:
        stock = Stock.query.filter_by(
            product_id=product.id, branch=branch
        ).first()
        result = product.to_dict()
        result['stock_qty'] = stock.quantity if stock else 0
        result['in_stock'] = bool(stock and stock.quantity > 0)
        results.append(result)
    return jsonify({'success': True, 'answer': answer, 'products': results})


with app.app_context():
    db.create_all()
    ensure_delivery_schema()


# RUN

if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        ensure_delivery_schema()
    app.run(debug=True, host='0.0.0.0', port=5000)
