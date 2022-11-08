CREATE SCHEMA IF NOT EXISTS admin;

DROP TABLE IF EXISTS admin.claims;

CREATE TABLE admin.claims (
    id int,
    name varchar(100),
    dob varchar(10),
    address varchar(250),
    phone varchar(50),
    claimdate varchar(20),
    city varchar(50),
    region varchar(50),
    amount int,
    receiveddate varchar(50) default (date_format(now(), '%Y-%m-%d %T'))
);