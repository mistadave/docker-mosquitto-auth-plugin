#!/bin/bash
docker-compose -f "docker-compose.yml" -p mosquittoauth down
docker volume rm mosquittoauth_mongodata 
