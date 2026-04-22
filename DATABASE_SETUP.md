# 📋 Hướng Dẫn Tạo Tables MySQL

## 📁 File Script
- **Vị trí**: `create_tables.sql` (ở root folder dự án)

---

## 🚀 Cách Chạy Script

### ✅ Cách 1: Dùng MySQL Command Line

```bash
# Chạy từ terminal/cmd
mysql -h localhost -u root -p acca_mdata < create_tables.sql
```

**Hoặc (nếu không có password):**
```bash
mysql -h localhost -u root acca_mdata < create_tables.sql
```

---

### ✅ Cách 2: Dùng MySQL Workbench

1. Mở **MySQL Workbench**
2. Kết nối đến MySQL server của bạn
3. Tạo database mới: `acca_mdata`
4. Mở file `create_tables.sql` (File → Open SQL Script)
5. Click **Execute** (Ctrl + Shift + Enter)

---

### ✅ Cách 3: Dùng phpMyAdmin

1. Mở **phpMyAdmin** (http://localhost/phpmyadmin)
2. Chọn database `acca_mdata`
3. Click tab **SQL**
4. Copy & paste nội dung từ `create_tables.sql`
5. Click **Execute**

---

### ✅ Cách 4: Dùng Node.js Script (Recommended)

Tôi sẽ tạo file JavaScript để chạy script:

```bash
npm run create-db
```

---

## 📊 Cấu Trúc Tables

### Table: Users
```
id              INT (Primary Key)
name            VARCHAR(255) - Tên người dùng
email           VARCHAR(255) - Email (Unique)
password        VARCHAR(255) - Mật khẩu (hashed)
role            VARCHAR(50) - 'user' hoặc 'admin'
createdAt       TIMESTAMP - Ngày tạo
updatedAt       TIMESTAMP - Ngày cập nhật cùng cuối
```

**Indexes:**
- `idx_email` - Tối ưu tìm kiếm theo email
- `idx_role` - Tối ưu filter theo role

---

### Table: Blogs
```
id              INT (Primary Key)
title           VARCHAR(255) - Tiêu đề bài viết
content         LONGTEXT - Nội dung bài viết
author          INT (Foreign Key) - ID người tác giả
createdAt       TIMESTAMP - Ngày tạo
updatedAt       TIMESTAMP - Ngày cập nhật cuối
```

**Relationships:**
- Foreign Key: `author` → `Users.id` (ON DELETE CASCADE)

**Indexes:**
- `idx_author` - Tối ưu lấy blogs theo tác giả
- `idx_createdAt` - Tối ưu sắp xếp theo ngày

---

## 🌱 Seed Data (Dữ liệu Mặc định)

Script sẽ tự động insert 2 users mặc định:

1. **Default User**
   - Email: `default@example.com`
   - Password: `password123` (đã hash)
   - Role: `user`

2. **Admin User**
   - Email: `admin@example.com`
   - Password: `password123` (đã hash)
   - Role: `admin`

**2 Blog posts** sẽ được tạo cho Default User.

---

## ⚠️ Lưu Ý Quan Trọng

1. **Database phải tồn tại**: Script sẽ tự tạo database `acca_mdata`
2. **MySQL phải chạy**: Đảm bảo MySQL service đang chạy
3. **Credentials**: Kiểm tra username/password phù hợp với `.env`
4. **Không xóa dữ liệu cũ**: Script dùng `IF NOT EXISTS` nên an toàn

---

## ✅ Kiểm Tra Sau Khi Tạo

Chạy lệnh để xem tables được tạo:

```sql
USE acca_mdata;
SHOW TABLES;
DESCRIBE Users;
DESCRIBE Blogs;
SELECT * FROM Users;
SELECT * FROM Blogs;
```

---

## 🔗 Phương Pháp Khác: Sequelize Auto-Sync

Bạn cũng có thể để **Sequelize tự động tạo** tables khi chạy ứng dụng:

```bash
npm start
```

Sequelize sẽ tự:
1. Connect đến MySQL
2. Check xem tables có tồn tại không
3. Nếu không → Tạo tables từ models
4. Chạy seed script tự động

Xem `src/server.js:19` - `sequelize.sync({ force: false })`

---

## 🆘 Troubleshooting

### Error: "Access denied for user 'root'@'localhost'"
```bash
# Cập nhật .env với password đúng
DB_PASSWORD=your_password
```

### Error: "Database acca_mdata doesn't exist"
```bash
# Script sẽ tự tạo, hoặc tạo manual:
CREATE DATABASE acca_mdata;
```

### Error: "Can't connect to MySQL server"
- Kiểm tra MySQL service có đang chạy
- Windows: `Services` → `MySQL80` → Start
- Linux: `sudo systemctl start mysql`

---

## 📌 Tóm Tắt

| Phương pháp | Ưu điểm | Nhược điểm |
|------------|---------|-----------|
| **SQL Script** | Nhanh, trực tiếp, dễ backup | Cần MySQL CLI |
| **Workbench** | GUI, dễ dùng, trực quan | Cần cài phần mềm riêng |
| **phpMyAdmin** | Web-based, tiện | Cần setup phpMyAdmin |
| **Sequelize Auto** | Tự động, đồng bộ code | Phụ thuộc app chạy |

