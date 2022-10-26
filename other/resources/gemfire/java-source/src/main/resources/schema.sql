BEGIN
   EXECUTE IMMEDIATE 'DROP TABLE claims';
EXCEPTION
   WHEN OTHERS THEN
      IF SQLCODE != -942 THEN
         RAISE;
      END IF;
END;


CREATE TABLE claims (
    id number(9,0),
    name varchar2(100),
    dob varchar2(10),
    address varchar2(250),
    phone varchar2(50),
    claimdate varchar2(20),
    city varchar2(50),
    region varchar2(50),
    amount number(9,0)
);