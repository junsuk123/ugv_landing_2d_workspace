# 기호

| 기호 | 의미 |
|---|---|
| $t$, $\Delta t_s$, $\Delta t_p$ | 시간, 물리 주기 0.01 s, 정책 주기 0.10 s |
| $x_D,x_G,z_D$ | 드론·UGV 월드 수평 위치, 드론 월드 고도 |
| $h$ | 추정 패드 기준 드론 고도 |
| $e_x=x_G-x_D$ | 수평 상대 위치 |
| $v_{rel,x}=v_G-v_D$ | 수평 상대속도 |
| $\theta,\dot\theta$ | pitch, pitch rate |
| $\theta_C$ | 카메라 pitch offset |
| $m=\tan(-\theta_C)$ | 광축 접근 곡면 기울기 |
| $e_c=e_x-mh$ | 접근 곡면 cross-track (평가 지표의 aim error $e_{aim}$와 같다) |
| $v_c=v_{rel,x}-mv_z$ | 접근 곡면 closure error |
| $I_G,\tau_G$ | 영상 갱신 여부, 정규화 age |
| $I_D,\tau_D$ | navigation 유효도, 정규화 age |
| $o_t\in\mathbb R^{12}$ | 공통 관측 |
| $X_t\in\mathbb R^{6\times7}$ | 온톨로지 노드 특징 |
| $r$, $\alpha_{ij}^{(r)}$ | 관계 유형, typed attention weight |
| $g_t\in\mathbb R^{16}$ | factorized graph embedding |
| $u_t\in[-1,1]^2$ | 정책 정규화 행동 |
| $a_t=[a_x,a_z]$ | 실제 적용 가속도 명령 |
| $m,p$ | UGV 운동 요인(0 CV, 1 CA), 관측 요인(0 정상, 1 누락) |
| $I_L=L_{11}-L_{10}-L_{01}+L_{00}$ | 2×2 사례의 상호작용 (S4−S3−S2+S1) |
| $\Delta v,\delta e_x$ | 초기 상대속도, 광축 기준점 대비 초기 위치 편차 |
