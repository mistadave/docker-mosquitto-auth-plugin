#!/usr/bin/env bash
set - eu

mongo -- mqGate<<EOF
    var admin = db.getSiblingDB('admin');
    admin.auth('root', 'mqtt');

    var mqDB = 'mqGate'
    var user = 'mqtt';
    var passwd = 'mqtt';
    db.createUser({user: user, pwd: passwd, roles: [{role: "read", db: mqDB}]});
    db.createCollection("users");
    db.users.insert({"username": "user1", "password": "PBKDF2\$sha256\$10000\$9D0XLHLBXowu1s0R\$YLm2tf9JJ9jLY1ty2MZRsHNM5j4tNLAo", "superuser": false, "topics": {"public/#": "r", "test": "rw"} });
EOF