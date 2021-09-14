#!/bin/bash

echo "select * from view_client_results" | mysql -umeva -pmeva -h 127.0.0.1 --port=3310 -t meva1
