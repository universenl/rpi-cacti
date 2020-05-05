#!/bin/bash
set -e

# Enter working dir
cd /var/www/html

# Process docker secrets
source secrets

echo "Starting apache"
apache2-foreground