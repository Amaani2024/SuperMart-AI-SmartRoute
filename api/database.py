# database.py
# ─────────────────────────────────────────────────────────
# This file defines ALL the database tables for SuperMart AI
# SQLAlchemy converts Python classes into database tables
# Think of each class = one table in the database
# ─────────────────────────────────────────────────────────

from flask_sqlalchemy import SQLAlchemy
from datetime import datetime
from sqlalchemy import inspect, text

# db is the database object — we connect it to Flask in app.py
db = SQLAlchemy()

# ══ TABLE 1: Users ════════════════════════════════════════
# Stores both managers and customers
# role = "manager" or "customer"
class User(db.Model):
    id         = db.Column(db.Integer, primary_key=True)
    name       = db.Column(db.String(100), nullable=False)
    email      = db.Column(db.String(120), unique=True, nullable=False)
    password   = db.Column(db.String(200), nullable=False)
    role       = db.Column(db.String(20),  nullable=False)  # manager / customer
    branch     = db.Column(db.String(5),   nullable=True)   # A, B, or C (managers only)
    phone      = db.Column(db.String(20),  nullable=True)
    address    = db.Column(db.String(200), nullable=True)   # customers only
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id'      : self.id,
            'name'    : self.name,
            'email'   : self.email,
            'role'    : self.role,
            'branch'  : self.branch,
            'phone'   : self.phone,
            'address' : self.address,
        }

# ══ TABLE 2: Products ═════════════════════════════════════
# The product catalog — all items the supermarket sells
class Product(db.Model):
    id           = db.Column(db.Integer, primary_key=True)
    name         = db.Column(db.String(150), nullable=False)
    category     = db.Column(db.String(100), nullable=False)  # product line
    price        = db.Column(db.Float,       nullable=False)
    unit         = db.Column(db.String(50),  nullable=True)   # kg, g, ml, piece
    description  = db.Column(db.String(300), nullable=True)
    image_url    = db.Column(db.String(300), nullable=True)
    is_available = db.Column(db.Boolean, default=True)
    created_at   = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id'          : self.id,
            'name'        : self.name,
            'category'    : self.category,
            'price'       : self.price,
            'unit'        : self.unit,
            'description' : self.description,
            'image_url'   : self.image_url,
            'is_available': self.is_available,
        }

# ══ TABLE 3: Stock ════════════════════════════════════════
# Inventory levels per product per branch
# Each branch has its own stock count for each product
class Stock(db.Model):
    id            = db.Column(db.Integer, primary_key=True)
    product_id    = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    branch        = db.Column(db.String(5), nullable=False)   # A, B, or C
    quantity      = db.Column(db.Integer,   nullable=False, default=0)
    min_quantity  = db.Column(db.Integer,   nullable=False, default=10)  # alert threshold
    last_updated  = db.Column(db.DateTime,  default=datetime.utcnow)

    # Link to Product table so we can get product name easily
    product = db.relationship('Product', backref='stocks')

    def to_dict(self):
        return {
            'id'           : self.id,
            'product_id'   : self.product_id,
            'product_name' : self.product.name if self.product else '',
            'category'     : self.product.category if self.product else '',
            'price'        : self.product.price if self.product else 0,
            'branch'       : self.branch,
            'quantity'     : self.quantity,
            'min_quantity' : self.min_quantity,
            'is_low'       : self.quantity <= self.min_quantity,
            'last_updated' : self.last_updated.strftime('%Y-%m-%d %H:%M'),
        }

# ══ TABLE 4: Staff ════════════════════════════════════════
# Staff members assigned to branches
class Staff(db.Model):
    id         = db.Column(db.Integer, primary_key=True)
    name       = db.Column(db.String(100), nullable=False)
    role       = db.Column(db.String(80),  nullable=False)  # Cashier, Supervisor etc
    branch     = db.Column(db.String(5),   nullable=False)
    phone      = db.Column(db.String(20),  nullable=True)
    shift      = db.Column(db.String(20),  nullable=False)  # Morning / Evening / Night
    shift_start= db.Column(db.String(10),  nullable=False)  # "08:00"
    shift_end  = db.Column(db.String(10),  nullable=False)  # "16:00"
    is_active  = db.Column(db.Boolean, default=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id'         : self.id,
            'name'       : self.name,
            'role'       : self.role,
            'branch'     : self.branch,
            'phone'      : self.phone,
            'shift'      : self.shift,
            'shift_start': self.shift_start,
            'shift_end'  : self.shift_end,
            'is_active'  : self.is_active,
        }

# ══ TABLE 5: Orders ═══════════════════════════════════════
# Customer orders — both pickup and delivery
class Order(db.Model):
    id           = db.Column(db.Integer, primary_key=True)
    customer_id  = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    branch       = db.Column(db.String(5),   nullable=False)
    order_type   = db.Column(db.String(20),  nullable=False)  # pickup / delivery
    status       = db.Column(db.String(30),  nullable=False, default='pending')
    # pending → confirmed → preparing → ready → rider_assigned
    # → out_for_delivery → rider_nearby → delivered
    total_amount = db.Column(db.Float, nullable=False, default=0.0)

    # Doorstep delivery details
    delivery_address = db.Column(db.String(300), nullable=True)
    delivery_latitude = db.Column(db.Float, nullable=True)
    delivery_longitude = db.Column(db.Float, nullable=True)
    delivery_landmark = db.Column(db.String(200), nullable=True)
    delivery_instructions = db.Column(db.String(300), nullable=True)
    contactless_delivery = db.Column(db.Boolean, nullable=False, default=False)
    delivery_fee = db.Column(db.Float, nullable=False, default=0.0)
    delivery_distance = db.Column(db.Float, nullable=False, default=0.0)
    delivery_slot = db.Column(db.String(60), nullable=True)
    estimated_delivery_minutes = db.Column(db.Integer, nullable=True)
    delivery_pin = db.Column(db.String(4), nullable=True)
    driver_id = db.Column(db.Integer, db.ForeignKey('driver.id'), nullable=True)
    delivered_at = db.Column(db.DateTime, nullable=True)
    proof_image_url = db.Column(db.String(500), nullable=True)

    notes        = db.Column(db.String(200), nullable=True)
    created_at   = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at   = db.Column(db.DateTime, default=datetime.utcnow)

    customer = db.relationship('User', backref='orders')
    driver   = db.relationship('Driver', backref='orders')
    items    = db.relationship('OrderItem', backref='order', lazy=True)

    def to_dict(self, include_pin=True):
        data = {
            'id'                        : self.id,
            'customer_id'               : self.customer_id,
            'customer_name'             : self.customer.name if self.customer else '',
            'branch'                    : self.branch,
            'order_type'                : self.order_type,
            'status'                    : self.status,
            'total_amount'              : self.total_amount,
            'delivery_address'          : self.delivery_address,
            'delivery_latitude'         : self.delivery_latitude,
            'delivery_longitude'        : self.delivery_longitude,
            'delivery_landmark'         : self.delivery_landmark,
            'delivery_instructions'     : self.delivery_instructions,
            'contactless_delivery'      : self.contactless_delivery,
            'delivery_fee'              : self.delivery_fee,
            'delivery_distance'         : self.delivery_distance,
            'delivery_slot'             : self.delivery_slot,
            'estimated_delivery_minutes': self.estimated_delivery_minutes,
            'driver_id'                 : self.driver_id,
            'driver'                    : self.driver.to_dict() if self.driver else None,
            'delivered_at'              : self.delivered_at.strftime('%Y-%m-%d %H:%M') if self.delivered_at else None,
            'proof_image_url'           : self.proof_image_url,
            'notes'                     : self.notes,
            'items'                     : [i.to_dict() for i in self.items],
            'created_at'                : self.created_at.strftime('%Y-%m-%d %H:%M'),
            'updated_at'                : self.updated_at.isoformat() if self.updated_at else None,
        }
        if include_pin:
            data['delivery_pin'] = self.delivery_pin
        return data

# ══ TABLE 6: OrderItems ═══════════════════════════════════
# Individual products inside each order
class OrderItem(db.Model):
    id         = db.Column(db.Integer, primary_key=True)
    order_id   = db.Column(db.Integer, db.ForeignKey('order.id'),   nullable=False)
    product_id = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    quantity   = db.Column(db.Integer, nullable=False)
    unit_price = db.Column(db.Float,   nullable=False)

    product = db.relationship('Product')

    def to_dict(self):
        return {
            'product_id'  : self.product_id,
            'product_name': self.product.name if self.product else '',
            'quantity'    : self.quantity,
            'unit_price'  : self.unit_price,
            'subtotal'    : round(self.quantity * self.unit_price, 2),
        }


# ══ TABLE 7: Delivery Drivers ═════════════════════════════
class Driver(db.Model):
    id                   = db.Column(db.Integer, primary_key=True)
    name                 = db.Column(db.String(100), nullable=False)
    phone                = db.Column(db.String(20), nullable=False)
    vehicle_number       = db.Column(db.String(30), nullable=False)
    branch               = db.Column(db.String(5), nullable=False)
    current_latitude     = db.Column(db.Float, nullable=True)
    current_longitude    = db.Column(db.Float, nullable=True)
    availability_status  = db.Column(db.String(30), nullable=False, default='available')
    last_location_update = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id'                  : self.id,
            'name'                : self.name,
            'phone'               : self.phone,
            'vehicle_number'      : self.vehicle_number,
            'branch'              : self.branch,
            'current_latitude'    : self.current_latitude,
            'current_longitude'   : self.current_longitude,
            'availability_status' : self.availability_status,
            'last_location_update': self.last_location_update.isoformat() if self.last_location_update else None,
        }


def ensure_delivery_schema():
    """Add delivery columns to older SQLite/PostgreSQL databases.

    db.create_all() creates new tables but does not add new columns to an
    existing order table. This lightweight migration keeps the old demo data.
    """
    inspector = inspect(db.engine)
    if 'order' not in inspector.get_table_names():
        return

    existing = {column['name'] for column in inspector.get_columns('order')}
    additions = {
        'delivery_latitude': 'DOUBLE PRECISION',
        'delivery_longitude': 'DOUBLE PRECISION',
        'delivery_landmark': 'VARCHAR(200)',
        'delivery_instructions': 'VARCHAR(300)',
        'contactless_delivery': 'BOOLEAN DEFAULT FALSE NOT NULL',
        'delivery_fee': 'DOUBLE PRECISION DEFAULT 0 NOT NULL',
        'delivery_distance': 'DOUBLE PRECISION DEFAULT 0 NOT NULL',
        'delivery_slot': 'VARCHAR(60)',
        'estimated_delivery_minutes': 'INTEGER',
        'delivery_pin': 'VARCHAR(4)',
        'driver_id': 'INTEGER',
        'delivered_at': 'TIMESTAMP',
        'proof_image_url': 'VARCHAR(500)',
    }
    for name, sql_type in additions.items():
        if name not in existing:
            db.session.execute(text(
                f'ALTER TABLE "order" ADD COLUMN {name} {sql_type}'
            ))
    db.session.commit()

# ══ TABLE 8: Alerts ═══════════════════════════════════════
# System alerts for managers — low stock, peak hours etc
class Alert(db.Model):
    id         = db.Column(db.Integer, primary_key=True)
    branch     = db.Column(db.String(5),   nullable=False)
    type       = db.Column(db.String(50),  nullable=False)
    # low_stock / peak_hour / high_sales / staff_needed
    message    = db.Column(db.String(300), nullable=False)
    is_read    = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    def to_dict(self):
        return {
            'id'        : self.id,
            'branch'    : self.branch,
            'type'      : self.type,
            'message'   : self.message,
            'is_read'   : self.is_read,
            'created_at': self.created_at.strftime('%Y-%m-%d %H:%M'),
        }


# ══ TABLE 9: Login Audit ═════════════════════════════════
class LoginAudit(db.Model):
    """Authentication audit trail. Passwords and tokens are never stored."""
    id         = db.Column(db.Integer, primary_key=True)
    user_id    = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=True)
    email      = db.Column(db.String(120), nullable=False)
    role       = db.Column(db.String(20), nullable=True)
    branch     = db.Column(db.String(5), nullable=True)
    success    = db.Column(db.Boolean, nullable=False)
    ip_address = db.Column(db.String(64), nullable=True)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    user = db.relationship('User')

    def to_dict(self):
        return {
            'id': self.id,
            'user_id': self.user_id,
            'name': self.user.name if self.user else '',
            'email': self.email,
            'role': self.role,
            'branch': self.branch,
            'success': self.success,
            'ip_address': self.ip_address,
            'created_at': self.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        }
