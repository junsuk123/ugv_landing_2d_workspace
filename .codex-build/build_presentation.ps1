$ErrorActionPreference = 'Stop'

$root = (Resolve-Path '.').Path
$asset = Join-Path $root 'docs\assets\paper\latest_parameter_matched'
$outDir = Join-Path $root 'results\presentation\final'
$renderDir = Join-Path $outDir 'rendered'
New-Item -ItemType Directory -Force -Path $outDir,$renderDir | Out-Null

$pptx = Join-Path $outDir 'ontology_rgat_ppo_v319_final.pptx'
$pdf = Join-Path $outDir 'ontology_rgat_ppo_v319_final.pdf'
if (Test-Path $pptx) { Remove-Item -LiteralPath $pptx -Force }
if (Test-Path $pdf) { Remove-Item -LiteralPath $pdf -Force }
Get-ChildItem $renderDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$pp = New-Object -ComObject PowerPoint.Application
$pp.Visible = -1
$pres = $pp.Presentations.Add()
$pres.PageSetup.SlideWidth = 960
$pres.PageSetup.SlideHeight = 540

$BLUE = 0xA55B20       # RGB(32,91,165) in Office BGR
$PURPLE = 0xA35C5D     # RGB(93,92,163) placeholder overridden by RGB helper
$GREEN = 0x6AA03A
$NAVY = 0x452818
$DARK = 0x26221F
$GRAY = 0x6B625B
$LIGHT = 0xF4F1ED
$WHITE = 0xFFFFFF

function RGB([int]$r,[int]$g,[int]$b) { return $r + 256*$g + 65536*$b }
$BLUE = RGB 32 91 165
$PURPLE = RGB 92 45 153
$GREEN = RGB 52 160 110
$ORANGE = RGB 239 159 45
$RED = RGB 210 74 65
$NAVY = RGB 20 42 70
$DARK = RGB 37 37 37
$GRAY = RGB 98 104 113
$LIGHT = RGB 246 247 249
$MID = RGB 220 224 230
$WHITE = RGB 255 255 255

function Set-Font($range, [double]$size, [int]$color=$DARK, [bool]$bold=$false, [string]$name='맑은 고딕') {
    $range.Font.Name = $name
    try { $range.Font.NameFarEast = $name } catch {}
    $range.Font.Size = $size
    $range.Font.Color.RGB = $color
    $range.Font.Bold = [int]$bold * -1
}

function Add-Text($slide,[string]$text,[double]$x,[double]$y,[double]$w,[double]$h,[double]$size=20,[int]$color=$DARK,[bool]$bold=$false,[int]$align=1) {
    $s = $slide.Shapes.AddTextbox(1,$x,$y,$w,$h)
    $s.TextFrame.MarginLeft = 0; $s.TextFrame.MarginRight = 0
    $s.TextFrame.MarginTop = 0; $s.TextFrame.MarginBottom = 0
    $s.TextFrame.WordWrap = -1
    $s.TextFrame.TextRange.Text = $text
    Set-Font $s.TextFrame.TextRange $size $color $bold
    $s.TextFrame.TextRange.ParagraphFormat.Alignment = $align
    return $s
}

function Add-Title($slide,[string]$title,[string]$subtitle='') {
    Add-Text $slide $title 54 30 852 44 27 $NAVY $true 1 | Out-Null
    $line = $slide.Shapes.AddShape(1,54,82,852,3)
    $line.Fill.ForeColor.RGB = $PURPLE; $line.Line.Visible = 0
    if ($subtitle) { Add-Text $slide $subtitle 54 91 852 24 12 $GRAY $false 1 | Out-Null }
}

function Add-Footer($slide,[int]$n,[string]$scope='planar_visibility_v2') {
    Add-Text $slide $scope 54 512 240 16 8.5 $GRAY $false 1 | Out-Null
    Add-Text $slide ([string]$n) 876 512 30 16 8.5 $GRAY $false 3 | Out-Null
}

function Add-PictureFit($slide,[string]$path,[double]$x,[double]$y,[double]$w,[double]$h) {
    $pic = $slide.Shapes.AddPicture($path,0,-1,0,0,-1,-1)
    $scale = [Math]::Min($w/$pic.Width,$h/$pic.Height)
    $pic.Width = $pic.Width*$scale; $pic.Height = $pic.Height*$scale
    $pic.Left = $x + ($w-$pic.Width)/2; $pic.Top = $y + ($h-$pic.Height)/2
    return $pic
}

function Add-PictureCropFill($slide,[string]$path,[double]$x,[double]$y,[double]$w,[double]$h) {
    $pic = $slide.Shapes.AddPicture($path,0,-1,0,0,-1,-1)
    $sourceW = [double]$pic.Width; $sourceH = [double]$pic.Height
    $sourceAspect = $sourceW/$sourceH; $targetAspect = $w/$h
    if ($sourceAspect -lt $targetAspect) {
        $visibleH = $sourceW/$targetAspect
        $crop = ($sourceH-$visibleH)/2
        $pic.PictureFormat.CropTop = $crop
        $pic.PictureFormat.CropBottom = $crop
    } elseif ($sourceAspect -gt $targetAspect) {
        $visibleW = $sourceH*$targetAspect
        $crop = ($sourceW-$visibleW)/2
        $pic.PictureFormat.CropLeft = $crop
        $pic.PictureFormat.CropRight = $crop
    }
    $pic.LockAspectRatio = 0
    $pic.Left = $x; $pic.Top = $y; $pic.Width = $w; $pic.Height = $h
    return $pic
}

function Add-Table($slide,$headers,$rows,[double]$x,[double]$y,[double]$w,[double]$h,$widths=$null) {
    $shape = $slide.Shapes.AddTable($rows.Count+1,$headers.Count,$x,$y,$w,$h)
    $table = $shape.Table
    if ($widths) { for($c=1;$c -le $headers.Count;$c++){ $table.Columns.Item($c).Width=$widths[$c-1] } }
    for($c=1;$c -le $headers.Count;$c++){
        $cell=$table.Cell(1,$c).Shape
        $cell.Fill.ForeColor.RGB=$NAVY
        $cell.TextFrame.TextRange.Text=[string]$headers[$c-1]
        Set-Font $cell.TextFrame.TextRange 12 $WHITE $true
        $cell.TextFrame.TextRange.ParagraphFormat.Alignment=2
    }
    for($r=1;$r -le $rows.Count;$r++){
        for($c=1;$c -le $headers.Count;$c++){
            $cell=$table.Cell($r+1,$c).Shape
            $cell.Fill.ForeColor.RGB= if($r%2 -eq 1){$LIGHT}else{$WHITE}
            $cell.TextFrame.TextRange.Text=[string]$rows[$r-1][$c-1]
            Set-Font $cell.TextFrame.TextRange 11.5 $DARK ($c -eq 1)
            $cell.TextFrame.TextRange.ParagraphFormat.Alignment= if($c -eq 1){1}else{2}
            $cell.TextFrame.MarginLeft=6; $cell.TextFrame.MarginRight=6
        }
    }
    return $shape
}

function Add-BulletList($slide,$items,[double]$x,[double]$y,[double]$w,[double]$h,[double]$size=18,[int]$color=$DARK) {
    $text = ($items | ForEach-Object { "• $_" }) -join "`r"
    $s=Add-Text $slide $text $x $y $w $h $size $color $false 1
    $s.TextFrame.TextRange.ParagraphFormat.SpaceAfter=9
    return $s
}

# 1. Cover
$s=$pres.Slides.Add(1,12); $s.FollowMasterBackground=0; $s.Background.Fill.Solid(); $s.Background.Fill.ForeColor.RGB=$NAVY
$bar=$s.Shapes.AddShape(1,0,0,18,540); $bar.Fill.ForeColor.RGB=$PURPLE; $bar.Line.Visible=0
Add-Text $s '이동 UGV 착륙을 위한' 70 92 820 38 22 (RGB 190 198 210) $false 1 | Out-Null
Add-Text $s '온톨로지–R-GAT PPO v3.19' 70 139 820 74 42 $WHITE $true 1 | Out-Null
Add-Text $s '동일 관측·보상·환경·파라미터에서 상태 표현만 비교' 70 230 760 42 22 (RGB 223 226 232) $false 1 | Out-Null
Add-Text $s 'Held-out 착륙률 95% → 98%   |   Unsafe 0%   |   6,101 = 6,101 parameters' 70 338 820 35 18 (RGB 204 180 236) $true 1 | Out-Null
Add-Text $s 'CICS 2026 발표자료  ·  MATLAB R2025b 실험 결과' 70 468 720 24 12 (RGB 172 183 198) $false 1 | Out-Null

# 2. Fair comparison
$s=$pres.Slides.Add(2,12); Add-Title $s '공정 비교 조건' '상태 표현을 제외한 학습·환경 계약을 고정'
$headers=@('항목','공통 설정')
$rows=@(
 @('입력','12차원 인과적 센서 관측 oₜ'),
 @('행동','[aₓ, a_z], 한계 2.5 / 2.0 m/s²'),
 @('환경','x–z 평면, 100 Hz 물리, 10 Hz 정책'),
 @('보상·종료','reward_v5, direct policy, 동일 접촉 조건'),
 @('학습 예산','750 PPO update × 6 episode = 4,500 episode'),
 @('모델 용량','일반 PPO 6,101 = v3.19 6,101 parameters'),
 @('선택·평가','validation 선택, held-out 100회 최종 평가')
)
Add-Table $s $headers $rows 60 125 840 325 @(205,635) | Out-Null
Add-Text $s '평면 실험에는 안전 감독기, 착륙 승인, SAFE_ABORT guard가 없다.' 60 466 840 28 15 $RED $true 2 | Out-Null
Add-Footer $s 2

# 3. Pipeline
$s=$pres.Slides.Add(3,12); Add-Title $s '최종 비교 파이프라인' '동일한 관측에서 일반 MLP와 관계형 상태 표현으로 분기'
Add-PictureFit $s (Join-Path $asset 'current_pipeline.svg') 55 120 850 335 | Out-Null
Add-Text $s '차이는 Actor/Critic에 들어가는 상태 표현뿐이며, 환경과 reward_v5는 공유한다.' 95 466 770 28 16 $NAVY $true 2 | Out-Null
Add-Footer $s 3

# 4. Observation
$s=$pres.Slides.Add(4,12); Add-Title $s '12차원 공통 관측과 정보 경계'
Add-Text $s 'oₜ = [ eₓ, h, v_rel,x, v̂_G,x, v_z, sinθ, cosθ, θ̇, I_G, τ_G, I_D, τ_D ]ᵀ ∈ ℝ¹²' 60 128 840 55 23 $NAVY $true 2 | Out-Null
Add-Text $s '허용 정보' 75 220 350 32 20 $BLUE $true 1 | Out-Null
Add-BulletList $s @('현재·과거 센서 측정','인과적 UGV 상태 추정','영상·측위 유효성과 age') 75 260 360 130 17 $DARK | Out-Null
Add-Text $s '제외 정보' 525 220 350 32 20 $PURPLE $true 1 | Out-Null
Add-BulletList $s @('패드 참값과 미래 상태','reward·outcome·tracker 판단','감독기 문맥과 절대 수평 위치') 525 260 360 130 17 $DARK | Out-Null
Add-Text $s '두 방법은 동일한 oₜ를 받는다. v3.19의 그래프는 oₜ의 결정론적 함수다.' 75 425 810 42 18 $NAVY $true 2 | Out-Null
Add-Footer $s 4

# 5. Ontology
$s=$pres.Slides.Add(5,12); Add-Title $s 'v3.19 온톨로지' '7개 노드, 4개 관계 유형, 의미 간선 9개와 자기 간선 7개'
Add-PictureFit $s (Join-Path $asset 'current_ontology.svg') 80 120 800 330 | Out-Null
Add-Text $s '물리·센서 관계를 보존하되 제어 gate나 hidden truth를 추가하지 않는다.' 85 465 790 28 16 $NAVY $true 2 | Out-Null
Add-Footer $s 5

# 6. Smooth features
$s=$pres.Slides.Add(6,12); Add-Title $s 'Smooth energy와 age confidence'
Add-Text $s '접근 곡면' 65 124 390 28 18 $BLUE $true 1 | Out-Null
Add-Text $s "m = tan(−θ_C)`re_c = eₓ − mh`rv_c = v_rel,x − mv_z" 65 160 390 112 25 $NAVY $true 2 | Out-Null
Add-Text $s '센서 confidence' 505 124 390 28 18 $PURPLE $true 1 | Out-Null
Add-Text $s "c_G = max(0, 1 − 0.5τ_G)`rc_D = max(0, 1 − 0.5τ_D)" 505 168 390 95 25 $NAVY $true 2 | Out-Null
Add-BulletList $s @('물리 노드는 제곱 에너지와 signed 값을 함께 보존','age confidence는 graph feature만 연속 가중','추론 후처리, action residual, descent gate 없음') 100 320 760 125 18 $DARK | Out-Null
Add-Footer $s 6

# 7. RGAT
$s=$pres.Slides.Add(7,12); Add-Title $s 'Typed R-GAT과 grouped readout'
Add-Text $s 'ℓⱼᵢ⁽ʳ⁾ = LReLU₀.₂( aᵣᵀ [Wᵣxⱼ ∥ Wᵣxᵢ ∥ eᵣ] )' 80 128 800 42 24 $NAVY $true 2 | Out-Null
Add-Text $s 'αⱼᵢ⁽ʳ⁾ = exp(ℓⱼᵢ⁽ʳ⁾) / [ Σ₍ₖ→ᵢ,ᵣ′₎ exp(ℓₖᵢ⁽ʳ′⁾) + 10⁻⁹ ]' 80 190 800 48 22 $NAVY $false 2 | Out-Null
Add-Text $s 'gₜ = tanh { b_g + Σₖ₌₁⁷ (W_c hₖ) ⊙ wₖ } ∈ ℝ¹⁶' 80 275 800 48 25 $PURPLE $true 2 | Out-Null
Add-BulletList $s @('관계별 변환·attention으로 이종 물리 관계를 분리','노드별 factorized weight로 정보 보존 grouped readout','PPO Actor와 Critic은 같은 16차원 relation state 사용') 105 355 750 115 17 $DARK | Out-Null
Add-Footer $s 7

# 8. Model capacity
$s=$pres.Slides.Add(8,12); Add-Title $s '파라미터 정합과 학습 전용 일관성 항'
$headers=@('구성','일반 PPO','온톨로지–R-GAT PPO v3.19')
$rows=@(
 @('Actor','12–48–48–2','R-GAT–16–38–37–2'),
 @('Critic','12–48–48–1','R-GAT–16–35–34–1'),
 @('학습 파라미터','6,101','6,101'),
 @('학습 예산','4,500 episode','4,500 episode'),
 @('추론 메모리','없음','없음')
)
Add-Table $s $headers $rows 55 130 850 260 @(185,255,410) | Out-Null
Add-Text $s 'Temporal consistency weight = 0.03' 80 420 360 30 18 $PURPLE $true 1 | Out-Null
Add-Text $s '인접 on-policy 상태의 tanh(mean) 변화만 학습 중 규제하며 추론 경로는 바꾸지 않는다.' 80 456 800 38 15 $DARK $false 1 | Out-Null
Add-Footer $s 8

# 9. Learning curve
$s=$pres.Slides.Add(9,12); Add-Title $s 'Validation 학습 곡선' '동일한 4,500-episode 예산, held-out seed는 checkpoint 선택에 사용하지 않음'
Add-PictureCropFill $s (Join-Path $asset 'parameter_matched_learning_curve.png') 72 113 816 382 | Out-Null
Add-Footer $s 9

# 10. Held-out
$s=$pres.Slides.Add(10,12); Add-Title $s 'Held-out 임무 성능' '서로소인 test seed 100회, 단일 학습 seed'
Add-PictureCropFill $s (Join-Path $asset 'parameter_matched_ontology_evidence.png') 55 108 850 390 | Out-Null
Add-Footer $s 10 'held-out n = 100  |  test seed는 선택에 미사용'

# 11. Validation robustness
$s=$pres.Slides.Add(11,12); Add-Title $s 'Sensor-noise 궤적 강건성' 'Validation 20 physical seeds × 20 paired-noise repeats'
Add-PictureFit $s (Join-Path $asset 'parameter_matched_consistency.png') 48 110 864 382 | Out-Null
Add-Footer $s 11 'validation 400 runs/method  |  unsafe 0% / 0%'

# 12. V2015
$s=$pres.Slides.Add(12,12); Add-Title $s 'V2015 조건부 Monte Carlo' 'Validation에서 선택한 어려운 한 물리 조건에 센서 잡음만 1,000회 반복'
Add-PictureCropFill $s (Join-Path $asset 'trajectory_mc_world_absolute.png') 55 108 850 390 | Out-Null
Add-Footer $s 12 'V2015 conditional stress test  |  held-out 일반화 결과가 아님'

# 13. Interpretation
$s=$pres.Slides.Add(13,12); Add-Title $s 'V2015 결과의 해석 범위'
Add-Text $s '무엇을 보여 주는가' 70 130 380 30 20 $PURPLE $true 1 | Out-Null
Add-BulletList $s @('동일 물리 조건에서 센서 잡음 민감도 비교','v3.19 착륙 1,000/1,000','평균 위치 분산 99.997% 감소') 70 170 390 135 18 $DARK | Out-Null
Add-Text $s '무엇을 뜻하지 않는가' 510 130 380 30 20 $BLUE $true 1 | Out-Null
Add-BulletList $s @('전체 held-out 성공률의 대체값 아님','다중 학습 seed 검증 아님','모든 조건의 통계적 우월성 아님') 510 170 390 135 18 $DARK | Out-Null
Add-Text $s '왼쪽 궤적은 월드 절대좌표 (x_D, z_D). 0.15×는 표시 종횡비이며 축 값은 실제 m다.' 80 365 800 55 18 $NAVY $true 2 | Out-Null
Add-Text $s '착륙 시간 분산은 validation에서 0.108776 → 0.709969 s²로 증가했다.' 80 438 800 32 15 $RED $true 2 | Out-Null
Add-Footer $s 13

# 14. Computation
$s=$pres.Slides.Add(14,12); Add-Title $s '계산 비용과 실시간성'
$headers=@('지표','일반 PPO','v3.19','해석')
$rows=@(
 @('학습 파라미터','6,101','6,101','정확히 정합'),
 @('Actor inference','0.0699 ms','0.4540 ms','6.5× 증가'),
 @('정책 주기','100 ms','100 ms','둘 다 주기 내'),
 @('추론 후처리','없음','없음','동일'),
 @('실시간 역전파','없음','없음','동일')
)
Add-Table $s $headers $rows 55 135 850 255 @(180,175,175,320) | Out-Null
Add-Text $s 'v3.19의 Actor 추론은 정책 주기의 0.454%이며, 관계형 표현의 계산 증가가 10 Hz 제어를 제한하지 않는다.' 75 430 810 52 18 $NAVY $true 2 | Out-Null
Add-Footer $s 14

# 15. Conclusion
$s=$pres.Slides.Add(15,12); $s.FollowMasterBackground=0; $s.Background.Fill.Solid(); $s.Background.Fill.ForeColor.RGB=$NAVY
Add-Text $s '결론' 70 50 820 50 30 (RGB 204 180 236) $true 1 | Out-Null
Add-Text $s '95% → 98%' 70 135 250 60 39 $WHITE $true 1 | Out-Null
Add-Text $s 'held-out 착륙률' 70 198 250 28 16 (RGB 190 198 210) $false 1 | Out-Null
Add-Text $s '0% / 0%' 360 135 220 60 39 $WHITE $true 1 | Out-Null
Add-Text $s 'unsafe' 360 198 220 28 16 (RGB 190 198 210) $false 1 | Out-Null
Add-Text $s '99.77%' 640 135 220 60 39 $WHITE $true 1 | Out-Null
Add-Text $s 'validation 위치 분산 감소' 640 198 250 28 16 (RGB 190 198 210) $false 1 | Out-Null
Add-Text $s '동일한 12차원 관측과 6,101개 파라미터 조건에서 관계를 보존한 상태 표현이 임무 성능과 센서 잡음 궤적 일관성을 함께 개선했다.' 95 290 770 90 23 $WHITE $true 2 | Out-Null
Add-Text $s '한계: 단일 학습 seed, V2015는 조건부 stress test, 착륙 시간 분산 증가' 95 420 770 32 14 (RGB 205 211 221) $false 2 | Out-Null
Add-Text $s 'Ontology–R-GAT PPO v3.19' 70 492 360 18 10 (RGB 160 172 190) $false 1 | Out-Null

$pres.SaveAs($pptx,24)
$pres.SaveAs($pdf,32)
$pres.Export($renderDir,'PNG',1920,1080)
$pres.Close()
$pp.Quit()
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($pres) | Out-Null
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($pp) | Out-Null
[GC]::Collect(); [GC]::WaitForPendingFinalizers()

Write-Output $pptx
Write-Output $pdf
Write-Output $renderDir
