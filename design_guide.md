# 바이브코딩 디자인 가이드

---

## 핵심 원칙

### 1. 필요없는 건 다 제거

**색상 제한**
- 기본: 흑백 모노톤 2가지 (`#000000`, `#FFFFFF`)
- 허용 확장: 강조색 1개 추가 (총 3색 이내)
- 그레이스케일 중간값 (`#F5F5F5`, `#E0E0E0`, `#9E9E9E`) 은 색상 카운트에 미포함

**제거 대상 목록**
- 장식용 아이콘 (기능 없는 아이콘 전부)
- 그림자 (`box-shadow`) — 플랫 레이아웃 유지
- 그라디언트 — 단색으로 대체
- 테두리 (`border`) — 여백으로 영역 구분
- 애니메이션 — 스크롤 트리거, 필요한 것만

**판단 기준:** "이게 없으면 정보 전달이 안 되나?" → 아니라면 제거

---

### 2. 레퍼런스에서 시작

레퍼런스를 먼저 캡처한 뒤 프롬프트에 넘긴다.

**레퍼런스 사이트**
- [Dribbble](https://dribbble.com) — UI 컴포넌트, 레이아웃 아이디어
- [Awwwards](https://www.awwwards.com/) — 고퀄리티 랜딩페이지
- [21st.dev](https://21st.dev) — 컴포넌트 단위 디자인 + 코드

**레퍼런스 활용 프롬프트**
```
[캡처 이미지 첨부]
이 디자인의 레이아웃 구조와 타이포그래피 스타일을 참고해서
우리 서비스에 맞게 재구성해줘.
색상은 흑백 모노톤으로 유지해.
```

---

### 3. 목적에 따라 디자인

구현 전에 반드시 물어봐야 할 것:

```
이 페이지의 주요 행동 유도 목표가 뭐야?
(예: 회원가입 / 데모 신청 / 앱 다운로드)
```

목표가 정해지면 CTA 버튼 문구, 위치, 색상을 그에 맞게 결정한다.

---

## 실전 가이드 — 컴포넌트별

---

### STEP 1. 배경 설정

**배경 영상 설정 프롬프트**
```
[영상 파일 경로 또는 URL]을 랜딩페이지의 배경으로 반복 재생되게 해줘.
전체화면으로 보여야 해.
영상 위에 어두운 오버레이(opacity 0.4~0.6)를 깔아서 텍스트 가독성을 확보해줘.
```

**CSS 기준값**
```css
video {
  position: fixed;
  top: 0; left: 0;
  width: 100%; height: 100%;
  object-fit: cover;
  z-index: -1;
}
.overlay {
  background: rgba(0, 0, 0, 0.5);
  position: absolute;
  inset: 0;
}
```

---

### STEP 2. Navbar 설정

**프롬프트**
```
navbar를 만들어줘.
1. 배경을 투명하게 처리해줘. 경계선도 필요없어.
2. 스크롤 했을 때 배경이 불투명해지면서 영역이 생기는 처리를 해줘.
   backdrop-filter: blur()로 흐릿하게 처리하면 될 것 같아.
3. 중앙에 링크 3~5개를 넣어주고,
   CTA 버튼으로 [목적에 맞는 문구]를 사용해줘.
```

**스펙 요약**

| 속성 | 기본 상태 | 스크롤 후 |
|------|----------|-----------|
| background | transparent | rgba(0,0,0,0.7) |
| backdrop-filter | none | blur(12px) |
| border-bottom | none | 1px solid rgba(255,255,255,0.1) |
| transition | — | all 0.3s ease |

**CSS 기준값**
```css
.navbar {
  position: fixed;
  top: 0; width: 100%;
  padding: 1.5rem 2rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
  transition: background 0.3s ease, backdrop-filter 0.3s ease;
  z-index: 100;
}
.navbar.scrolled {
  background: rgba(0, 0, 0, 0.7);
  backdrop-filter: blur(12px);
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}
```

**CTA 버튼 문구 예시**

| 서비스 유형 | CTA 문구 |
|------------|----------|
| SaaS | Get Started / Start Free |
| 앱 | Download Now / Try Free |
| 에이전시 | Book a Call / See Work |
| 커뮤니티 | Join Now / Apply |

---

### STEP 3. Hero 섹션 설정

**프롬프트**
```
hero 섹션의 카피를 수정해줘.
우리 서비스의 핵심이 드러나게 메인 텍스트를 한 문장 이내로 작성해줘.
정말 필요하다면 서브 텍스트를 1~2줄로 추가해줘.
애플의 카피라이팅 기법을 사용해.
폰트는 구글 폰트에서 선정해줘.
배경(영상)과 대조되는 버튼으로 행동 유도 장치를 만들어줘.
```

**애플식 카피라이팅 원칙**
- 기능 나열 X → 변화(결과)를 말한다
- 예: "AI 기반 일정 관리 앱" → "하루가 두 배로 늘어납니다"
- 짧을수록 강하다. 10단어 이내가 기준

**폰트 추천 조합 (Google Fonts)**

| 용도 | 폰트 |
|------|------|
| 임팩트 헤드라인 | Inter, Syne, Space Grotesk |
| 세련된 헤드라인 | Cormorant Garamond, Playfair Display |
| 가독성 높은 본문 | Inter, Noto Sans KR (한국어) |
| 미니멀 | DM Sans, Manrope |

**헤드라인 크기 기준**
```css
h1 {
  font-size: clamp(2.5rem, 6vw, 5rem);
  font-weight: 700;
  line-height: 1.1;
  letter-spacing: -0.02em;
}
```

**CTA 버튼 — 배경과 대조되게**
```css
/* 배경이 어두울 때 */
.cta-button {
  background: #FFFFFF;
  color: #000000;
  padding: 0.875rem 2rem;
  font-weight: 600;
  border-radius: 999px;   /* 완전 둥글게 */
  border: none;
  cursor: pointer;
  transition: transform 0.2s ease, opacity 0.2s ease;
}
.cta-button:hover {
  transform: scale(1.04);
  opacity: 0.92;
}
```

---

### STEP 4. 전체 페이지 색상 정리

구현 후 반드시 실행:

```
전체 페이지에서 사용된 색상을 목록으로 뽑아줘.
3가지를 초과하면 가장 적게 사용된 색상부터 제거해서 3가지 이내로 줄여줘.
```

**허용 색상 구조 예시**

| 역할 | 색상 |
|------|------|
| 배경 | #000000 또는 #FFFFFF |
| 텍스트 | 반대색 (#FFFFFF 또는 #000000) |
| 강조 (CTA) | 단 하나의 포인트 컬러 |

---

### STEP 5. 제품 by 제품 섹션 (Features)

**각 섹션 공통 원칙**
- 섹션 간 구분: `border` 제거 → 여백(`padding: 6rem 0`)으로 구분
- 이미지/스크린샷: 실제 제품 화면 사용. 목업 프레임 최소화
- 텍스트 최대 2열 레이아웃 (모바일은 1열)

**프롬프트 패턴**
```
[기능명] 섹션을 만들어줘.
왼쪽에 기능 설명 텍스트, 오른쪽에 스크린샷.
색상은 기존 팔레트(흑백 + [강조색]) 유지.
불필요한 장식 요소 없이 깔끔하게.
```

---

## 체크리스트 (배포 전)

- [ ] 사용된 색상 3가지 이내
- [ ] 장식용 아이콘 전부 제거
- [ ] CTA 버튼 목적에 맞는 문구
- [ ] 모바일 반응형 확인
- [ ] 배경 영상 오버레이로 텍스트 가독성 확보
- [ ] 폰트 2종 이내 (헤드라인 + 본문)
- [ ] Navbar 스크롤 효과 동작 확인
