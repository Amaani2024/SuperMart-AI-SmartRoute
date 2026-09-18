# seed_data.py
# ─────────────────────────────────────────────────────────
# Run this ONCE to fill the database with sample data
# python seed_data.py
# ─────────────────────────────────────────────────────────

from app import app, db
from database import (
    User, Product, Stock, Staff, Order, OrderItem, Driver, Alert, LoginAudit
)
from datetime import datetime
import bcrypt

def seed():
    with app.app_context():
        # Create all tables
        db.create_all()
        print("✓ Tables created")

        # Clear existing data
        LoginAudit.query.delete()
        Alert.query.delete()
        OrderItem.query.delete()
        Order.query.delete()
        Driver.query.delete()
        Stock.query.delete()
        Staff.query.delete()
        Product.query.delete()
        User.query.delete()
        db.session.commit()
        print("✓ Old data cleared")

        # ── USERS ─────────────────────────────────────────
        pw = bcrypt.hashpw("password123".encode(), bcrypt.gensalt()).decode()

        users = [
            User(name="Manager A",  email="manager.a@supermart.com",
                 password=pw, role="manager", branch="A", phone="077-111-1111"),
            User(name="Manager B",  email="manager.b@supermart.com",
                 password=pw, role="manager", branch="B", phone="077-222-2222"),
            User(name="Manager C",  email="manager.c@supermart.com",
                 password=pw, role="manager", branch="C", phone="077-333-3333"),
            User(name="Staff A", email="staff.a@supermart.com",
                 password=pw, role="staff", branch="A", phone="077-100-1000"),
            User(name="Hamdhan",    email="hamdhan@customer.com",
                 password=pw, role="customer", phone="077-444-4444",
                 address="123 Main St, Colombo"),
            User(name="Dilishiya", email="dilishiya@customer.com",
                 password=pw, role="customer", phone="077-555-5555",
                 address="45 Lake Rd, Kandy"),
            User(name="Ahmed",     email="ahmed@customer.com",
                 password=pw, role="customer", phone="077-666-6666",
                 address="78 Hill St, Galle"),
        ]
        db.session.add_all(users)
        db.session.commit()
        print("✓ Users created")

        # ── PRODUCTS ──────────────────────────────────────
        products = [
            # Health and Beauty
            Product(name="Colgate Toothpaste 150g",      category="Health and beauty",
                    price=3.50, unit="piece",
                    description="Whitening toothpaste with fluoride protection"),
            Product(name="Sunsilk Shampoo 350ml",         category="Health and beauty",
                    price=4.20, unit="bottle",
                    description="Nourishing shampoo for smooth silky hair"),
            Product(name="Nivea Face Cream 50ml",         category="Health and beauty",
                    price=8.90, unit="jar",
                    description="Moisturizing face cream for daily use"),
            Product(name="Dettol Antiseptic 500ml",       category="Health and beauty",
                    price=5.60, unit="bottle",
                    description="Antiseptic liquid for cuts and wounds"),
            Product(name="Panadol Tablets 20s",           category="Health and beauty",
                    price=2.80, unit="pack",
                    description="Pain relief paracetamol tablets"),

            # Food and Beverages
            Product(name="Basmati Rice 5kg",             category="Food and beverages",
                    price=12.50, unit="bag",
                    description="Premium long grain basmati rice"),
            Product(name="Milo 400g",                    category="Food and beverages",
                    price=6.80, unit="tin",
                    description="Chocolate malt energy drink powder"),
            Product(name="Coca Cola 1.5L",               category="Food and beverages",
                    price=2.20, unit="bottle",
                    description="Classic refreshing cola drink"),
            Product(name="Anchor Butter 250g",           category="Food and beverages",
                    price=4.50, unit="pack",
                    description="Premium quality salted butter"),
            Product(name="Eggs (Tray of 30)",            category="Food and beverages",
                    price=9.00, unit="tray",
                    description="Fresh farm eggs"),

            # Electronic Accessories
            Product(name="Samsung USB-C Cable 1m",       category="Electronic accessories",
                    price=8.50, unit="piece",
                    description="Fast charging USB-C data cable"),
            Product(name="Generic Earphones",            category="Electronic accessories",
                    price=5.90, unit="piece",
                    description="In-ear stereo earphones with mic"),
            Product(name="Phone Screen Protector",       category="Electronic accessories",
                    price=3.20, unit="piece",
                    description="Universal tempered glass screen protector"),
            Product(name="AA Batteries 4-pack",          category="Electronic accessories",
                    price=4.10, unit="pack",
                    description="Long-lasting alkaline batteries"),

            # Fashion Accessories
            Product(name="Ladies Handbag",              category="Fashion accessories",
                    price=24.90, unit="piece",
                    description="Stylish everyday shoulder handbag"),
            Product(name="Men's Belt",                  category="Fashion accessories",
                    price=12.50, unit="piece",
                    description="Genuine leather casual belt"),
            Product(name="Sunglasses",                  category="Fashion accessories",
                    price=15.00, unit="piece",
                    description="UV400 protection sunglasses"),

            # Home and Lifestyle
            Product(name="Dettol Floor Cleaner 1L",     category="Home and lifestyle",
                    price=4.80, unit="bottle",
                    description="Antibacterial floor cleaning liquid"),
            Product(name="Glad Cling Wrap 30m",         category="Home and lifestyle",
                    price=3.60, unit="roll",
                    description="Food-safe cling film wrap"),
            Product(name="Philips LED Bulb 9W",         category="Home and lifestyle",
                    price=6.20, unit="piece",
                    description="Energy-saving LED light bulb"),

            # Sports and Travel
            Product(name="Gym Water Bottle 750ml",      category="Sports and travel",
                    price=7.50, unit="piece",
                    description="BPA-free stainless steel water bottle"),
            Product(name="Travel Neck Pillow",          category="Sports and travel",
                    price=11.90, unit="piece",
                    description="Memory foam travel neck support pillow"),
            Product(name="Protein Bar (Box of 12)",     category="Sports and travel",
                    price=18.00, unit="box",
                    description="High protein chocolate flavour energy bars"),
        ]
        db.session.add_all(products)
        db.session.commit()
        print(f"✓ {len(products)} products created")

        # ── STOCK per branch ──────────────────────────────
        branches = ["A", "B", "C"]
        import random
        random.seed(42)

        stock_entries = []
        for product in products:
            for branch in branches:
                qty = random.randint(5, 150)
                min_qty = 10
                stock_entries.append(Stock(
                    product_id=product.id,
                    branch=branch,
                    quantity=qty,
                    min_quantity=min_qty
                ))
        db.session.add_all(stock_entries)
        db.session.commit()
        print(f"✓ {len(stock_entries)} stock entries created")

        # ── STAFF ─────────────────────────────────────────
        staff_list = [
            # Branch A
            Staff(name="Kamal Perera",   role="Cashier",    branch="A",
                  shift="Morning", shift_start="08:00", shift_end="16:00",
                  phone="077-101-0001"),
            Staff(name="Nimali Silva",   role="Cashier",    branch="A",
                  shift="Evening", shift_start="14:00", shift_end="22:00",
                  phone="077-101-0002"),
            Staff(name="Ruwan Fernando", role="Supervisor", branch="A",
                  shift="Morning", shift_start="08:00", shift_end="16:00",
                  phone="077-101-0003"),
            Staff(name="Amaya Kumari",   role="Stock Clerk",branch="A",
                  shift="Morning", shift_start="06:00", shift_end="14:00",
                  phone="077-101-0004"),

            # Branch B
            Staff(name="Saman Bandara",  role="Cashier",    branch="B",
                  shift="Morning", shift_start="08:00", shift_end="16:00",
                  phone="077-102-0001"),
            Staff(name="Dilini Jayawardena", role="Cashier", branch="B",
                  shift="Evening", shift_start="14:00", shift_end="22:00",
                  phone="077-102-0002"),
            Staff(name="Lahiru Wijesinghe", role="Supervisor", branch="B",
                  shift="Evening", shift_start="14:00", shift_end="22:00",
                  phone="077-102-0003"),
            Staff(name="Priya Nair",     role="Stock Clerk",branch="B",
                  shift="Morning", shift_start="06:00", shift_end="14:00",
                  phone="077-102-0004"),

            # Branch C
            Staff(name="Kasun Rajapaksa", role="Cashier",  branch="C",
                  shift="Morning", shift_start="08:00", shift_end="16:00",
                  phone="077-103-0001"),
            Staff(name="Madhavi Dissanayake",role="Cashier",branch="C",
                  shift="Evening", shift_start="14:00", shift_end="22:00",
                  phone="077-103-0002"),
            Staff(name="Tharaka Gunasekara",role="Supervisor",branch="C",
                  shift="Morning", shift_start="08:00", shift_end="16:00",
                  phone="077-103-0003"),
            Staff(name="Shanaya Cooray",  role="Stock Clerk",branch="C",
                  shift="Morning", shift_start="06:00", shift_end="14:00",
                  phone="077-103-0004"),
        ]
        db.session.add_all(staff_list)
        db.session.commit()
        print(f"✓ {len(staff_list)} staff members created")

        # ── DELIVERY DRIVERS ──────────────────────────────
        drivers = [
            Driver(name="Mohamed Rizwan", phone="077-701-1001",
                   vehicle_number="CP BCD-4582", branch="A",
                   current_latitude=7.2906, current_longitude=80.6337),
            Driver(name="Nuwan Perera", phone="077-702-1002",
                   vehicle_number="CP BFG-2210", branch="B",
                   current_latitude=7.2631, current_longitude=80.5967),
            Driver(name="Fathima Nirosha", phone="077-703-1003",
                   vehicle_number="CP BKM-9044", branch="C",
                   current_latitude=7.3334, current_longitude=80.6215),
        ]
        db.session.add_all(drivers)
        db.session.commit()
        print(f"✓ {len(drivers)} delivery drivers created")

        # ── ALERTS ────────────────────────────────────────
        alerts = [
            Alert(branch="A", type="low_stock",
                  message="Colgate Toothpaste is running low — only 8 units remaining"),
            Alert(branch="A", type="peak_hour",
                  message="Peak hour approaching (2:00 PM) — consider scheduling extra cashier"),
            Alert(branch="B", type="high_sales",
                  message="Branch B exceeded daily income target by 23% — great performance!"),
            Alert(branch="C", type="low_stock",
                  message="Milo 400g is running low — only 6 units remaining at Branch C"),
        ]
        db.session.add_all(alerts)
        db.session.commit()
        print(f"✓ {len(alerts)} alerts created")

        print("\n Database seeded successfully!")
        print("   Logins (all use password: password123):")
        print("   Manager A → manager.a@supermart.com")
        print("   Manager B → manager.b@supermart.com")
        print("   Customer  → hamdhan@customer.com")

if __name__ == "__main__":
    seed()
