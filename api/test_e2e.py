"""Repeatable API integration test using the configured local database."""

from uuid import uuid4

from app import app
from database import db, LoginAudit, Order, OrderItem, Product, Staff, Stock, User


def run():
    client = app.test_client()
    email = f"viva-test-{uuid4().hex[:10]}@example.com"
    customer_id = None
    order_id = None
    stock_id = None
    staff_id = None
    original_quantity = None

    try:
        registration = client.post("/auth/register", json={
            "name": "Viva Test Customer",
            "email": email,
            "password": "Secure123!",
            "phone": "0770000000",
            "address": "1 Cloud Avenue, Colombo",
        })
        assert registration.status_code == 200, registration.get_json()
        customer_id = registration.get_json()["user"]["id"]

        with app.app_context():
            saved = db.session.get(User, customer_id)
            assert saved is not None
            assert saved.email == email
            assert saved.password != "Secure123!"
            stock = (
                Stock.query.filter_by(branch="A")
                .order_by(Stock.quantity.desc())
                .first()
            )
            assert stock and stock.quantity > 1
            stock_id = stock.id
            original_quantity = stock.quantity
            product_id = stock.product_id

        login = client.post("/auth/login", json={
            "email": email,
            "password": "Secure123!",
        })
        assert login.status_code == 200, login.get_json()
        customer_headers = {
            "Authorization": f"Bearer {login.get_json()['token']}"
        }

        placed = client.post("/orders/place", json={
            "customer_id": customer_id,
            "branch": "A",
            "order_type": "delivery",
            "delivery_address": "1 Cloud Avenue, Colombo",
            "items": [{"product_id": product_id, "quantity": 1}],
        }, headers=customer_headers)
        assert placed.status_code == 200, placed.get_json()
        order_id = placed.get_json()["order"]["id"]

        assert client.get(
            f"/orders/customer/{customer_id}", headers=customer_headers
        ).status_code == 200
        assert client.get(
            f"/customer/offers/{customer_id}", headers=customer_headers
        ).status_code == 200
        denied = client.get("/manager/stock/A", headers=customer_headers)
        assert denied.status_code == 403

        manager_login = client.post("/auth/login", json={
            "email": "manager.a@supermart.com",
            "password": "password123",
        })
        assert manager_login.status_code == 200
        manager_headers = {
            "Authorization": f"Bearer {manager_login.get_json()['token']}"
        }
        added_staff = client.post("/manager/staff/add", json={
            "name": "Viva Test Staff",
            "role": "Cashier",
            "branch": "A",
            "phone": "0770000001",
            "shift": "Morning",
            "shift_start": "08:00",
            "shift_end": "16:00",
        }, headers=manager_headers)
        assert added_staff.status_code == 200, added_staff.get_json()
        staff_id = added_staff.get_json()["staff"]["id"]
        removed_staff = client.post("/manager/staff/update", json={
            "staff_id": staff_id,
            "is_active": False,
        }, headers=manager_headers)
        assert removed_staff.status_code == 200, removed_staff.get_json()
        assert removed_staff.get_json()["staff"]["is_active"] is False
        assert client.get(
            "/orders/branch/A", headers=manager_headers
        ).status_code == 200
        updated = client.post("/orders/update-status", json={
            "order_id": order_id,
            "status": "out_for_delivery",
        }, headers=manager_headers)
        assert updated.status_code == 200, updated.get_json()

        with app.app_context():
            assert db.session.get(Order, order_id).status == "out_for_delivery"
            assert db.session.get(Stock, stock_id).quantity == original_quantity - 1

        print("Registration, persistence, login, checkout, offers, stock, and fulfilment passed.")
    finally:
        with app.app_context():
            if order_id:
                OrderItem.query.filter_by(order_id=order_id).delete()
                order = db.session.get(Order, order_id)
                if order:
                    db.session.delete(order)
                db.session.flush()
            if stock_id and original_quantity is not None:
                stock = db.session.get(Stock, stock_id)
                if stock:
                    stock.quantity = original_quantity
            if staff_id:
                staff = db.session.get(Staff, staff_id)
                if staff:
                    db.session.delete(staff)
            if customer_id:
                LoginAudit.query.filter_by(user_id=customer_id).delete()
                user = db.session.get(User, customer_id)
                if user:
                    db.session.delete(user)
            db.session.commit()


if __name__ == "__main__":
    run()
