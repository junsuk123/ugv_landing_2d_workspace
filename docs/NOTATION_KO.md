# 기호

| 기호 | 의미 |
|---|---|
| $t$, $\Delta t_s$, $\Delta t_p$ | 시간, 물리 주기 0.01 s, 정책 주기 0.10 s |
| $x_D,x_G$ | 드론·UGV 수평 위치 |
| $h$ | 추정 패드 기준 드론 고도 |
| $e_x=x_G-x_D$ | 수평 상대 위치 |
| $v_{rel,x}=v_G-v_D$ | 수평 상대속도 |
| $\theta,\dot\theta$ | pitch, pitch rate |
| $\theta_C$ | 카메라 pitch offset |
| $m=\tan(-\theta_C)$ | 광축 접근 곡면 기울기 |
| $e_c=e_x-mh$ | 접근 곡면 cross-track |
| $v_c=v_{rel,x}-mv_z$ | 접근 곡면 closure error |
| $o_t\in\mathbb R^{12}$ | 공통 관측 |
| $X_t\in\mathbb R^{6\times7}$ | 온톨로지 노드 특징 |
| $r$ | 관계 유형 |
| $\alpha_{ij}^{(r)}$ | typed attention weight |
| $g_t\in\mathbb R^{16}$ | factorized graph embedding |
| $u_t\in[-1,1]^2$ | 정책 정규화 행동 |
| $a_t=[a_x,a_z]$ | 실제 적용 가속도 명령 |
| $C_{valid}$ | 물리적 허용 행동 비율 |
| $D_{obs}$ | 관측 잡음에 따른 행동 거리 |
| $J_{policy}$ | 요청 명령 변화율 RMS |

평면 경로는 direct policy이므로 별도의 감독기 적용 행동 기호를 사용하지 않음.
