# 3D 바둑 교실 - 참고판 + SGF + 이중목소리 수정

## 날짜
2026-07-10

## 파일
dist/build/dot/classroom3d.html

## 추가/수정 기능
1. 오른쪽 위 고정 참고도 창 (AI 선생님 모달 밑)
   - 별도 3D 뷰(_refScene/_refCam/_refRenderer), 메인판 복제
   - showReference([{x,y,c,n}])/clearReference 함수
2. 참고판 대국 기능
   - 정지/재생(⏸/▶), 클릭 착수, 이전/다음(◀▶), 초기화(↺)
   - 사석 규칙(_refRemoveDead) 메인판과 동일
   - 순서번호 스프라이트
3. 참고판 드래그 회전(상하좌우) + 휠 줌 (_refCamUpdate)
4. SGF 기보 저장 (메인 컨트롤 옆 💾 SGF 저장)
   - history → 표준 SGF, 다운로드
   - 파일명: tobmate_space_go_YYYYMMDD_HHMM.sgf
5. [버그수정] 드래그/클릭 구분 (mousedown~click 총 이동거리 4px)
   - 참고판 드래그가 메인 착수 교란하던 문제
6. [버그수정] 이중 목소리 → _lectureInProgress 락
   - click 이벤트 중복 발생 시 lecture 중복 요청 차단
   - socket 수신 착수는 quiet(lecture 안 부름)

## 핵심 구조 (참고)
- N=19, CELL=0.35, BOARD=CELL*18=6.3
- 좌표→3D: (-BOARD/2+c*CELL, y, -BOARD/2+r*CELL)
- 돌: SphereGeometry(CELL*0.46), scale.y=0.55, 흑0x111111/백0xf5f5f5, y=1.16
- 음성: /avatar/eleven/speak (ElevenLabs), speaking + _lectureInProgress 이중 락
- 강의: /api/lecture (착수마다 1회)

## 알려진 잔여 이슈
- click 이벤트가 물리적으로 2번 발생 (참고판 이벤트 겹침 추정)
  → _lectureInProgress 락으로 증상 차단(목소리 1번). 근본원인 추후 정리 가능
- "AI 강의 이용량 초과" 메시지: lecture API rate limit (서버측)

## 향후
- AI 강의 변화도 → showReference 자동 연동 (강의 중 참고도 표시)
- 참고판에도 SGF 저장 옵션
