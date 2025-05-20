# 동적 DNS 업데이터 (Dynamic DNS Updater)

![AWS](https://img.shields.io/badge/AWS-Lambda-orange)
![AWS](https://img.shields.io/badge/AWS-Route53-blue)
![Python](https://img.shields.io/badge/Python-3.11-green)
![Terraform](https://img.shields.io/badge/Terraform-latest-purple)
![License](https://img.shields.io/badge/License-MIT-yellow.svg)

## 개발 동기

AWS EC2를 운영하면서 비용 최적화와 안정적인 도메인 접근성이라는 두 가지 목표 사이에서 균형을 맞추기 위해 본 프로젝트를 개발했습니다.

AWS에서 고정 IP를 유지하기 위한 일반적인 방법은 탄력적 IP(Elastic IP)를 사용하는 것입니다. 하지만 탄력적 IP는 지속적인 과금이 발생하며, 단순히 인스턴스 재시작 시에만 IP가 변경되는 환경에서는 불필요한 비용이 됩니다.

이 문제를 해결하기 위해, 본 프로젝트는 EC2 인스턴스의 IP가 변경될 때마다 자동으로 DNS 레코드를 업데이트하는 서버리스 자동화 솔루션을 구축했습니다. 이를 통해:

1. 탄력적 IP 사용 비용 절감
2. 동적 IP 환경에서도 일관된 도메인 접근성 보장
3. DevOps 작업 자동화로 운영 효율성 향상

이 자동화 솔루션은 AWS Lambda와 Route53 API를 활용하여 인프라 변경을 감지하고 자동으로 대응하는 클라우드 네이티브 접근방식을 채택했습니다. 

## 프로젝트 개요

동적 DNS 업데이터는 EC2 인스턴스의 공개 IP 주소를 자동으로 감지하고, AWS Route53의 DNS 레코드를 업데이트하는 서버리스 솔루션입니다. 이 프로젝트는 1분마다 실행되는 AWS Lambda 함수를 사용하여 EC2 인스턴스의 IP 주소가 변경될 때마다 DNS 레코드를 최신 상태로 유지합니다.

### 주요 기능

- EC2 인스턴스의 공개 IP 주소 실시간 모니터링
- Route53 DNS 레코드 자동 업데이트
- Webhook을 통한 IP 변경 알림
- CloudWatch 이벤트를 통한 1분 간격 실행
- 완전한 인프라 코드화(IaC) 접근방식 - Terraform 사용

### 비용 및 운영 최적화

본 프로젝트는 클라우드 리소스 관리의 중요한 원칙인 '비용 효율성'과 '즉각적인 대응성'을 균형 있게 달성하기 위한 설계를 적용했습니다:

- **로깅 비용 최적화**: EventBridge에서 발생하는 1분 간격의 Lambda 호출은 필연적으로 CloudWatch 로그 생성을 유발합니다. 이러한 누적된 로그는 장기간 보관 시 불필요한 비용이 발생할 수 있습니다. 이를 방지하기 위해 로그 보존 기간을 1일로 설정하여 스토리지 비용을 최소화했습니다.

- **웹훅 알림**: 모든 이벤트가 아닌 '의미 있는 변화'에만 알림을 발생시키도록 했고, IP 변경이 발생했거나 업데이트 시도가 실패한 경우에만 웹훅 통해 알림을 전송함으로써:
  1. 불필요한 알림 피로도 방지
  2. 실질적인 대응이 필요한 상황에만 집중
  3. 외부 API 호출 최소화를 통한 비용 절감

이러한 접근 방식을 통해 시스템은 비용 효율적으로 운영되면서도 문제 상황에 대한 즉각적인 인지와 대응이 가능합니다.

## 기술 스택

### 인프라
- **AWS Lambda**: 서버리스 함수 실행 환경
- **AWS Route53**: DNS 관리 서비스
- **AWS CloudWatch Events**: 예약된 이벤트 트리거
- **AWS IAM**: 권한 관리

### 개발
- **Python 3.11**: Lambda 함수 구현
- **Terraform**: 인프라스트럭처 관리
- **Bash**: 배포 및 빌드 스크립트
- **boto3**: AWS SDK for Python
- **requests**: HTTP 클라이언트 라이브러리

## 아키텍처

1. **CloudWatch Events**는 1분마다 Lambda 함수를 트리거합니다.
2. **Lambda 함수**는 지정된 EC2 인스턴스의 현재 공개 IP 주소를 확인합니다.
3. Lambda 함수는 Route53의 현재 DNS 레코드를 확인합니다.
4. IP 주소가 변경된 경우, Lambda 함수는 Route53 DNS 레코드를 새 IP 주소로 업데이트합니다.
5. 변경 사항이 발생하면 설정된 Webhook URL로 알림이 전송됩니다.

## 프로젝트 구조

```
dynamic-dns-updater/
├── deploy.sh                  # 전체 배포 스크립트
├── build.sh                   # Lambda 패키징 스크립트
├── lambda/
│   ├── lambda-function.py     # Lambda 함수 코드
│   └── requirements.txt       # Python 의존성
└── terraform/
    ├── main.tf                # Terraform 인프라 정의
    ├── variables.tf           # Terraform 변수 정의
    ├── outputs.tf             # Terraform 출력 정의
    └── variables.auto.tfvars  # 환경별 변수 값 (자동 생성)
```

## 주요 구현 상세

### Lambda 함수 (lambda-function.py)

Lambda 함수는 다음과 같은 주요 작업을 수행합니다:

1. **EC2 인스턴스 조회**: `boto3` 클라이언트를 사용하여 지정된 EC2 인스턴스의 공개 IP 주소를 가져옵니다.
2. **현재 DNS 레코드 조회**: Route53 API를 사용하여 현재 DNS A 레코드 값을 조회합니다.
3. **DNS 레코드 업데이트**: IP 주소가 변경된 경우, Route53 API를 사용하여 레코드를 업데이트합니다.
4. **알림 전송**: 변경 사항이 발생하면 Webhook URL로 알림을 전송합니다.

### Terraform 인프라 (main.tf)

Terraform 설정은 다음 리소스를 생성하고 관리합니다:

1. **IAM Role 및 Policy**: Lambda가 EC2와 Route53 API에 접근할 수 있는 권한을 부여합니다.
2. **Lambda 함수**: Python 런타임으로 함수를 배포하고 환경 변수를 설정합니다.
3. **CloudWatch Event Rule**: 1분마다 Lambda 함수를 트리거하는 이벤트 규칙을 생성합니다.
4. **CloudWatch Log Group**: Lambda 로그를 저장하고 1일 유지 정책을 설정합니다.

특히, 리소스 중복을 방지하기 위해 배포 전에 기존 Lambda 함수와 IAM 역할을 삭제하는 로직이 포함되어 있습니다.

## 빌드 및 배포 방법

### 사전 요구사항

- AWS CLI가 설치되어 있고 aws 프로필이 구성되어 있어야 합니다.
- Python 3.11 이상이 설치되어 있어야 합니다.
- Terraform이 설치되어 있어야 합니다.


### 전체 배포 프로세스

처음 배포하거나 설정을 변경하려는 경우, 전체 배포 스크립트를 사용합니다:

1. 프로젝트를 클론합니다:
   ```bash
   git clone https://github.com/sh5080/dynamic-dns-updater.git
   cd dynamic-dns-updater
   ```

2. 배포 권한을 설정합니다:
   ```bash
   chmod +x deploy.sh build.sh
   ```

3. 배포 스크립트를 실행합니다:
   ```bash
   ./deploy.sh
   ```

   배포 스크립트는 다음 단계를 순차적으로 수행합니다:
   - Terraform 변수 파일 생성 또는 재사용 여부 확인
   - 필요한 설정 정보 수집 (인스턴스 ID, 호스팅 영역 ID 등)
   - Lambda 함수 패키징 (build.sh 호출)
   - Terraform 초기화 및 리소스 생성/업데이트

4. 프롬프트에 따라 다음 정보를 입력합니다:
   - EC2 인스턴스 ID
   - Route53 호스팅 영역 ID
   - DNS 레코드 이름 (예: sub.example.com.)
   - Webhook URL (알림 수신용)

모든 단계가 완료되면 Lambda 함수가 배포되고 1분마다 실행되어 IP 주소를 모니터링하기 시작합니다.

## 유지 관리 및 모니터링

- Lambda 함수 로그는 CloudWatch 로그에서 확인할 수 있습니다.
- IP 주소 변경 알림은 설정된 Webhook URL로 전송됩니다.
- Lambda 코드 업데이트는 `build.sh` 스크립트를 실행한 후 Terraform을 다시 적용하여 수행할 수 있습니다.

## 보안 고려사항

- Lambda IAM 역할은 최소 권한 원칙을 따릅니다.
- 민감한 정보(웹훅 URL 등)는 Lambda 환경 변수로 관리됩니다.
- IP 주소가 변경될 때만 Route53 API 호출이 이루어져 API 호출을 최소화합니다.


## 문제 해결

- **DNS 업데이트가 발생하지 않는 경우**: CloudWatch 로그를 확인하여 Lambda 함수가 오류 없이 실행되는지 확인하세요.
- **권한 오류**: IAM 역할과 정책이 올바르게 구성되었는지 확인하세요.
- **Lambda 타임아웃**: 기본 타임아웃은 10초로 설정되어 있으며, 필요한 경우 Terraform 설정에서 조정할 수 있습니다.

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 LICENSE 파일을 참조하세요. 