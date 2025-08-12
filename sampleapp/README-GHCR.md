# 2025_openinfradays_k0s sampleapp (FluxCD 실습용 샘플 이미지)

이 이미지는 본 프로젝트의 FluxCD 실습을 위한 샘플 FastAPI 애플리케이션입니다.

- 이미지 레지스트리: `ghcr.io/hellices/2025_openinfradays_k0s`
- 포트: 8080 (Uvicorn)
- 헬스체크: `GET /healthz`
- API 문서: `GET /docs`

## 이미지 설명
- FastAPI로 구현된 간단한 CRUD 예시 앱입니다.
- In-memory(로컬 캐시) 저장소를 사용하며, 학습/데모 목적입니다.
- 컨테이너 실행 시 Uvicorn으로 0.0.0.0:8080에서 기동합니다.

### 로컬 실행 (도커)
```bash
docker run --rm -p 8080:8080 ghcr.io/hellices/2025_openinfradays_k0s:latest
# 확인
curl http://localhost:8080/healthz
```

## FluxCD로 배포하는 방법 (요약)
이 이미지는 본 레포지토리의 FluxCD 구성을 통해 배포되도록 준비되어 있습니다.
워크플로는 앱 매니페스트(Deployment/Service/kustomization/namespace)를 이미지 digest(@sha256:…)로 고정하여
OCI 아티팩트(ghcr.io/<owner>/<repo>:latest)로 GHCR에 푸시합니다. Flux는 이 아티팩트를 구독하고 digest 변경 시 자동으로 reconcile 합니다.

1) 클러스터에 Flux 설치 및 부트스트랩 적용
```bash
flux install
kubectl create ns flux-system --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f fluxcd/bootstrap/flux-bootstrap.yaml
kubectl -n flux-system get ocirepositories.source.toolkit.fluxcd.io
kubectl -n flux-system get kustomizations.kustomize.toolkit.fluxcd.io
```

2) 수동 테스트(선택): kustomize로 직접 적용
```bash
kubectl apply -k fluxcd/app
kubectl -n app get deploy,svc
```

참고: 상세한 실습 순서와 설명은 레포지토리 루트의 README를 확인하세요.
