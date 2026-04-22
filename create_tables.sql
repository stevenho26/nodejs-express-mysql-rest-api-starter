-- ============================================
-- MData API - Database Setup Script
-- ============================================
-- Database: acca_mdata
-- Date: 2026-04-22

-- Create Database (nếu chưa tồn tại)
CREATE DATABASE IF NOT EXISTS `acca_mdata`;
USE `acca_mdata`;

-- ============================================
-- Table: Users
-- ============================================
CREATE TABLE IF NOT EXISTS `Users` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `password` VARCHAR(255) NOT NULL,
  `role` VARCHAR(50) NOT NULL DEFAULT 'user' CHECK (`role` IN ('user', 'admin')),
  `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updatedAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_email` (`email`),
  INDEX `idx_role` (`role`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Table: Blogs
-- ============================================
CREATE TABLE IF NOT EXISTS `Blogs` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `title` VARCHAR(255) NOT NULL,
  `content` LONGTEXT NOT NULL,
  `author` INT NOT NULL,
  `createdAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updatedAt` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`author`) REFERENCES `Users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  INDEX `idx_author` (`author`),
  INDEX `idx_createdAt` (`createdAt`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================
-- Seed Default Data (Optional)
-- ============================================

-- Insert default user
INSERT INTO `Users` (`name`, `email`, `password`, `role`) VALUES
('Default User', 'default@example.com', '$2a$08$gKx2h0dIa4Y1h0dIa4Y1huYHcxoOOKJ0H1k0d0dIa4Y1h0dIa4Y1u', 'user'),
('Admin User', 'admin@example.com', '$2a$08$gKx2h0dIa4Y1h0dIa4Y1huYHcxoOOKJ0H1k0d0dIa4Y1h0dIa4Y1u', 'admin')
ON DUPLICATE KEY UPDATE `email`=VALUES(`email`);

-- Insert default blogs
INSERT INTO `Blogs` (`title`, `content`, `author`) VALUES
('First Blog Post', 'This is the content of the first blog post.', 1),
('Second Blog Post', 'This is the content of the second blog post.', 1)
ON DUPLICATE KEY UPDATE `title`=VALUES(`title`);

-- ============================================
-- Show Tables and Structure
-- ============================================
SHOW TABLES;
DESCRIBE `Users`;
DESCRIBE `Blogs`;
