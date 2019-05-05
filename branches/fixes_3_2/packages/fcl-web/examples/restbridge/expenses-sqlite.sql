create table t2(id integer primary key autoincrement);
insert into  sqlite_sequence (name,seq) values ('seqExpenseTypesID',1);
insert into  sqlite_sequence (name,seq) values ('seqExpenseID',1);
insert into  sqlite_sequence (name,seq) values ('seqUsersID',1);
insert into  sqlite_sequence (name,seq) values ('seqProjectsID',1);
drop table t2;
 
create table ExpenseTypes (
  etID bigint primary key,
  etName varchar(50) not null,
  etDescription varchar(100) not null,
  etMaxAmount decimal(10,2),
  etCost decimal(10,2) default 1,
  etActive boolean not null default true
);

create table Users (
  uID bigint primary key,
  uLogin varchar(50) not null,
  uFullName varchar(100) not null,
  uPassword varchar(100) not null,
  uActive boolean not null default true 
);

create table Projects (
  pID bigint primary key,
  pName varchar(50) not null,
  pDescription varchar(100) not null,
  pActive boolean not null default true
);

create table Expenses (
  eID bigint primary key,
  eUserFK bigint not null,
  eProjectFK bigint not null,
  eTypeFK bigint not null,
  eAmount decimal(10,2) not null,
  eDate date not null default CURRENT_DATE,
  eComment varchar(1024)
);

