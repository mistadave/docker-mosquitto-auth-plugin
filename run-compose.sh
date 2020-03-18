#!/bin/bash
PROJECT=mosquittoauth
docker-compose -f "docker-compose.yml" -p mosquittoauth up -d --build
sleep 5
docker exec mosquittoauth_mongo_1 /init-mongo.sh
