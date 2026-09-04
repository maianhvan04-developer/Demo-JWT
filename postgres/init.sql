\set ON_ERROR_STOP on

CREATE DATABASE keycloak;
CREATE DATABASE finance;

\connect finance

CREATE TABLE IF NOT EXISTS accounts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  owner VARCHAR(80) NOT NULL,
  account_no VARCHAR(40) UNIQUE NOT NULL,
  balance NUMERIC(18,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO accounts(owner, account_no, balance)
VALUES
  ('Alice Finance', 'LAB-001', 12500000.00),
  ('Demo Company', 'LAB-002', 28450000.00),
  ('Security Lab', 'LAB-003', 7300000.00)
ON CONFLICT (account_no) DO NOTHING;
