# 순장바둑 기보 계가(집표시) 작업 요약

## 날짜
2026-07-09

## 최종 해결책
- 대국 종료 시 계가 결과가 DB(gogames.result)에 저장돼 있음 ("B+15", "W+6", "W+T" 등)
- record API가 result를 안 내려줘서 클라가 못 읽던 문제 → API에 result 추가
- 클라(집표시)가 자체 floodFill 재계산 대신 공식 result를 표시

## 수정 파일
1. dist/goroom-api.js
   - /goroom-record/ 응답에 result, first_turn, kpmi 필드 추가

2. dist/build/custom.1781908372.js
   - window.buildBoard: lboard(GoBoard0 fiber, depth2, getstate(col,row), 1흑2백) 직접 읽기
   - showSJTerri: buildBoard → window.buildBoard 호출
   - resultTxt: 공식 result(DOM의 B+N/W+N) 우선 표시 (try-catch)
   - 우측 패널 제거, 좌측 모달(선수정보 하단)만 사용
   - canvas 하단 배너 제거

3. dist/build/sw-custom.js
   - custom.js를 network-first로 (캐시 지옥 방지)

4. dist/katago-middleware.js
   - /score2, /eval 엔드포인트 추가 (현재 미사용, 보류)

## 계가 로직 (참고)
- 순장(rule=2): 흑집 - 백집 + (호선이면 덤, 접바둑이면 덤 0)
- 실제 계가 엔진: go_train.exe (wine) eval_territory/auto_scoring
- board 인코딩: move = row<<8 | col (row=v>>8, col=v&0xFF), 색은 착수순 교대(백선), 패스=8224

## 보류 (B플랜)
- tboard(집 영역 맵)는 DB에 미저장 → 경계선은 현재 자체 floodFill (대부분 정확)
- 완벽하게 하려면 대국 종료 시 tboard도 DB 저장 필요
