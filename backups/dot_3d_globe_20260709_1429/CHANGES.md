# Dot Metaverse 3D 지구본 구현

## 날짜
2026-07-09

## 개요
2D 18×18 격자(324칸) 메타버스 맵을 3D 우주 지구본으로 시각화.
Three.js r128 + CSS3DRenderer + OrbitControls.

## 수정 파일
dist/build/dot.html

## 주요 작업
1. [버그수정] 파일 끝 잘림 복원
   - loadThreeLibraries 함수 미완결 → forEach/함수/script 닫기 추가
   - 623 IIFE(셀 분양 확장) 미닫힘 → loadServerCells() 뒤 })(); 삽입
   - 이게 toggleDimensionView/init3DGlobeEngine 미등록의 근본 원인이었음

2. [버그수정] 컨테이너 순서 버그
   - init3DGlobeEngine 시작부에서 globe-3d-view 없으면 즉시 생성
   - (기존: 컨테이너 생성 코드가 함수 맨 아래라 첫 호출 시 return으로 빠짐)

3. [기능] 실데이터 연동
   - 3D 셀 타일이 2D cells{} 맵 참조 → 실제 아이콘(ICONS)·type색(TCOLORS)·owner 표시
   - 소유 셀: 아이콘+진한색+강한발광 / 빈 셀: 위치기반 무지개 네온색

4. [기능] 우측 벽 제거 + 전체폭
   - 3D 진입 시 .info 패널 display:none, 2D 복귀 시 복원
   - 진입 후 globeCamera/globeRenderGL 리사이즈로 전체폭 채움

5. [기능] 줌 슬라이더 연결
   - #zsl(1~8) → 3D 카메라 거리 (dist=1900-v*190)
   - camera/controls/renderer를 window.globeXXX로 전역 노출

6. [기능] 우주 무지개 파티클
   - 2500개 별(반지름 700~2200, HSL 무지개색) + 120개 큰 별
   - AdditiveBlending 발광, animate에서 천천히 회전
   - _hslToRgb 헬퍼 함수 추가

## 핵심 데이터 구조 (참고)
- COLS = 'ABCDEFGHJKLMNOPQRS' (18열, I 제외)
- cells{} : id→{type,owner,name,isPortal,icon,color} (buildGrid가 채움)
- ICONS = {office:🏢,shop:🛒,game:🎮,meet:🤝,nft:💎,social:💬,portal:🌐,owned:🏠}
- TCOLORS = {office:#378add,shop:#F5A623,game:#27AE60,meet:#7B68EE,nft:#E23B3B,social:#1ABC9C,portal:#00d4ff}
- mapCellTo3DSphere: theta=(c/18)*2π, phi=((r+0.5)/18)*π, radius=430
- 레이아웃: main > map-wrap(#mapWrap) + info(우측패널)

## 캐시 주의
dot.html 변경 후 시크릿 창(Ctrl+Shift+N)으로 확인 (SW/메모리 캐시 우회)
