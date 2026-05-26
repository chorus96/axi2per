# axi2per — AXI4 to PULP Peripheral Bus Bridge

AXI4 슬레이브 인터페이스를 PULP 주변장치(peripheral) 마스터 인터페이스로 변환하는 SystemVerilog RTL 브리지 모듈입니다.

---

## 특징

- **가변 데이터 폭**: `AXI_DATA_WIDTH`와 `PER_DATA_WIDTH`를 독립적으로 설정 가능  
  - `BEAT_RATIO = PER_DATA_WIDTH / AXI_DATA_WIDTH` 만큼의 AXI 버스트로 주변장치 1워드 구성
- **AXI 버스트 지원**: AXI4 INCR 버스트(최대 256비트) → 주변장치 단일 트랜잭션
- **ID 인코딩 변환**: AXI ID(바이너리) → 주변장치 ID(원-핫)
  - `PER_ID_WIDTH = 2**AXI_ID_WIDTH` (기본값)
- **user 필드 전달**: AXI `aw_user`/`ar_user` → 주변장치 → AXI `b_user`/`r_user` 왕복 전달
- **PULP 표준 `we` 극성**: `per_master_we_o = 1` → 쓰기, `0` → 읽기
- **AXI 채널 버퍼**: AW/AR/W/R/B 채널에 FIFO 버퍼 내장 (`BUFFER_DEPTH` 설정)
- **Bender 의존성 관리**: `axi_slice` 버퍼 서브모듈 자동 취득
- **AMD Vivado IP 패키징 지원**: `s_axi_*`/`aclk`/`aresetn` 포트 명명 + `X_INTERFACE_INFO` 속성 + `scripts/package_ip.tcl`

---

## 블록 다이어그램

```
                    ┌─────────────────────────────────────────────┐
                    │                  axi2per                     │
                    │                                             │
 AXI4 Slave         │  ┌──────────┐   ┌──────────────────────┐  │
 ────────────────   │  │axi_aw_buf│   │  axi2per_req_channel  │  │   PULP Peripheral
  AW ─────────────► │─►│axi_ar_buf│──►│  - AXI → PER 변환    │─►│──► req/add/we
  AR ─────────────► │  │axi_w_buf │   │  - 쓰기 비트 수집    │  │    wdata/be
  W  ─────────────► │  └──────────┘   │  - ID 원-핫 변환     │  │    id/user/gnt
                    │                  └──────────┬───────────┘  │
                    │                 trans_req/  │ trans_r_valid │
                    │                 we/id/add/len              │
                    │                  ┌──────────▼───────────┐  │
  R  ◄─────────────  │  ┌──────────┐◄──│  axi2per_res_channel  │◄─│◄── r_valid
  B  ◄─────────────  │  │axi_r_buf │   │  - PER → AXI 변환    │  │    r_rdata
                    │  │axi_b_buf │   │  - 비트 슬라이싱     │  │    r_id/r_user
                    │  └──────────┘   │  - user 필드 전달    │  │
                    │                  └──────────────────────┘  │
                    └─────────────────────────────────────────────┘
```

---

## 파라미터

| 파라미터 | 기본값 | 설명 |
|---|---|---|
| `PER_DATA_WIDTH` | 256 | 주변장치 데이터 버스 폭 (비트) |
| `AXI_ADDR_WIDTH` | 32 | AXI 주소 버스 폭 (비트) |
| `AXI_DATA_WIDTH` | 64 | AXI 데이터 버스 폭 (비트) |
| `AXI_USER_WIDTH` | 6 | AXI user 신호 폭 (비트) |
| `AXI_ID_WIDTH` | 3 | AXI ID 폭 (바이너리, 비트) |
| `PER_ID_WIDTH` | `2**AXI_ID_WIDTH` | 주변장치 ID 폭 (원-핫, 비트) |
| `BUFFER_DEPTH` | 2 | AXI 채널 FIFO 버퍼 깊이 |

### 파생 로컬파라미터

| 로컬파라미터 | 값 | 설명 |
|---|---|---|
| `PER_ADDR_WIDTH` | `AXI_ADDR_WIDTH` | 주변장치 주소 버스 폭 — AXI와 항상 동일하므로 `localparam`으로 고정 |

### 데이터 폭 예시

| PER_DATA_WIDTH | AXI_DATA_WIDTH | BEAT_RATIO | AXI 버스트 길이 |
|---|---|---|---|
| 256 | 64 | 4 | 4비트 |
| 512 | 128 | 4 | 4비트 |
| 64 | 64 | 1 | 1비트 |

---

## 디렉토리 구조

```
axi2per/
├── src/                        # RTL 소스
│   ├── axi2per.sv              # 최상위 모듈 (AMD Vivado IP 패키징 지원)
│   ├── axi2per_req_channel.sv  # AXI → 주변장치 요청 변환
│   ├── axi2per_res_channel.sv  # 주변장치 응답 → AXI 변환
│   ├── axi2per.sv.kr.md        # 한국어 문서
│   ├── axi2per_req_channel.sv.kr.md
│   └── axi2per_res_channel.sv.kr.md
├── sim/                        # 시뮬레이션 소스
│   ├── tb_axi2per.sv           # 테스트벤치
│   ├── per_slave_model.sv      # 주변장치 슬레이브 모델
│   ├── tb_axi2per.sv.kr.md     # 한국어 문서
│   └── per_slave_model.sv.kr.md
├── scripts/                    # 빌드·설치 스크립트
│   ├── install_tools.sh        # Verilator + Bender 설치
│   ├── verilator_sim.sh        # 시뮬레이션 빌드·실행
│   ├── package_ip.tcl          # AMD Vivado IP 패키징 스크립트
│   ├── verilator.f             # RTL 파일리스트 스냅샷
│   ├── verilator_sim.f         # 시뮬레이션 파일리스트 스냅샷
│   ├── install_tools.sh.kr.md  # 한국어 문서
│   ├── verilator_sim.sh.kr.md
│   └── package_ip.tcl.kr.md   # 한국어 문서
├── Bender.yml                  # 의존성 선언
└── README.md
```

---

## 의존성

[Bender](https://github.com/pulp-platform/bender)로 관리됩니다.

| 패키지 | 버전 | 용도 |
|---|---|---|
| `axi_slice` | 1.1.4 | AXI 채널 FIFO 버퍼 (axi_aw/ar/w/r/b_buffer) |

---

## 빠른 시작

### 1. 도구 설치

```bash
bash scripts/install_tools.sh
```

Verilator(APT)와 Bender(소스 빌드)를 설치하고 프로젝트 의존성을 취득합니다.

### 2. 린트 검사

```bash
./scripts/verilator_sim.sh --lint-only
```

### 3. 시뮬레이션 실행

```bash
./scripts/verilator_sim.sh --sim
```

테스트벤치 `tb_axi2per`를 빌드하고 실행합니다.  
성공 시 출력:

```
ALL TESTS PASSED: user field correctly propagated AXI ↔ peripheral
```

### 4. 클린 빌드

```bash
./scripts/verilator_sim.sh --sim --clean
```

### 5. AMD Vivado IP 패키징

```bash
vivado -mode batch -source scripts/package_ip.tcl
```

`ip_output/axi2per/` 디렉토리와 `ip_output/axi2per_1.0.zip` 아카이브를 생성합니다.  
IP Catalog에서 직접 임포트하거나 zip 아카이브를 배포할 수 있습니다.

> **사전 조건**: `bender update`로 의존성을 먼저 취득하고, PART 변수를 타깃 FPGA에 맞게 수정하세요.

---

## 시뮬레이션 테스트

`tb_axi2per.sv`에서 다음 항목을 검증합니다 (PER_DATA_WIDTH=512, AXI_DATA_WIDTH=128):

| 테스트 | 주소 | AXI ID | user | 검증 항목 |
|---|---|---|---|---|
| Test 1 | `0x0080` | 1 | `0x15` | 쓰기→읽기 데이터, b_user/r_user 일치 |
| Test 2 | `0x0100` | 5 | `0x2A` | 다른 ID/user 독립 동작 확인 |
| Test 3 | `0x0080` | 2 | `0x3F` | 동일 주소 다른 user로 재읽기 (user 독립성) |

모니터 블록에서 `$onehot(per_id)` 런타임 검사로 원-핫 ID 인코딩을 매 사이클 검증합니다.

---

## 원-핫 ID 인코딩

```
AXI_ID_WIDTH=3 → PER_ID_WIDTH=8

AXI ID  │  주변장치 ID (원-핫)
   0    │  0000_0001
   1    │  0000_0010
   2    │  0000_0100
   3    │  0000_1000
   4    │  0001_0000
   5    │  0010_0000
   6    │  0100_0000
   7    │  1000_0000
```

---

## 한국어 문서 (Korean Documentation)

각 소스 파일에 대한 상세 한국어 문서 (블록 다이어그램 포함):

| 파일 | 문서 |
|---|---|
| `src/axi2per.sv` | [axi2per.sv.kr.md](src/axi2per.sv.kr.md) |
| `src/axi2per_req_channel.sv` | [axi2per_req_channel.sv.kr.md](src/axi2per_req_channel.sv.kr.md) |
| `src/axi2per_res_channel.sv` | [axi2per_res_channel.sv.kr.md](src/axi2per_res_channel.sv.kr.md) |
| `sim/per_slave_model.sv` | [per_slave_model.sv.kr.md](sim/per_slave_model.sv.kr.md) |
| `sim/tb_axi2per.sv` | [tb_axi2per.sv.kr.md](sim/tb_axi2per.sv.kr.md) |
| `scripts/install_tools.sh` | [install_tools.sh.kr.md](scripts/install_tools.sh.kr.md) |
| `scripts/verilator_sim.sh` | [verilator_sim.sh.kr.md](scripts/verilator_sim.sh.kr.md) |
| `scripts/package_ip.tcl` | [package_ip.tcl.kr.md](scripts/package_ip.tcl.kr.md) |

---

## 라이선스

Copyright 2018 ETH Zurich and University of Bologna.  
Solderpad Hardware License, Version 0.51 — [SHL-0.51](http://solderpad.org/licenses/SHL-0.51)
