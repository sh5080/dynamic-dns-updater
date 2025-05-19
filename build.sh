#!/bin/bash

# lambda 디렉토리로 이동
cd lambda || exit 1

# dependencies 설치
echo "Installing Python dependencies..."
rm -rf package lambda.zip
pip3 install --target ./package -r requirements.txt

# 패키징
echo "Packaging Lambda function..."
cd package || exit 1
zip -qr ../lambda.zip .
cd ..
zip -g lambda.zip lambda-function.py

# terraform 디렉토리로 이동시킴
echo "Moving lambda.zip to terraform directory..."
mv lambda.zip ../terraform/

echo "✅ Build complete. lambda.zip moved to terraform/"
