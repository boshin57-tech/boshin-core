# 2026-06-27 다국어 번역 적용 작업

## 수정 파일
- lecture.html: applyI18n() 함수 추가/확장, _LECTURE_I18N 번역 키 추가, __getLang() 함수명 수정
- ai-lecture.js: lang 파라미터 감지 로직 개선 (localStorage lang 인덱스 매핑 추가)
- custom.1781908372.js: 없음 (읽기전용)
- index.html: go_room 이동 시 lang 파라미터 자동 추가

## 지원 언어
ko(한국어), en(영어), zh(중국어), ja(일본어), ru(러시아어), ar(아랍어)

## 번역 적용 요소
- 상단 탭: AI Lecture / Pro Teacher / AI Avatar
- 좌측 메뉴: Lecture / Board / Students / Schedule / Kifu
- 버튼: Rec / Leave / Prev / Next / Reset / Live / Share / Score
- 채팅: Live Chat / Message (Enter)
- 상태: Connecting... / AI Instructor
- 통계: Students / Mode / Rating

## 2차 작업 (강의실 선택창 버튼 다국어)
- ai-lecture.js: 버튼 탐지 로직 다국어 확장 (강의시작 버튼 6개 언어 인식)
- ai-lecture.js: 프로기사/아바타 버튼 텍스트 다국어 동적 업데이트
- custom.1781908372.js: applyLectureI18n() window.i18n 의존성 제거, _lectureI18n 직접 사용

## 최종 완료 상태
- 강의실 선택창: 6개 언어 버튼 정상 표시
- 강의실 내부: 전체 UI 6개 언어 번역 완료
