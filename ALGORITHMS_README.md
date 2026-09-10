# InSoul Biomechanical & Gait Analysis Algorithms Documentation

This document provides a comprehensive technical and mathematical reference for all biomechanical, temporal, kinetic, and kinematic gait analysis algorithms implemented across the **InSoul** hardware (ESP32) and software (Flutter mobile platform).

---

## 1. Apparatus & Sensor Architecture

The InSoul system operates as a bilateral, instrumented smart insole system streaming real-time telemetry over Bluetooth Low Energy (BLE):

- **Bilateral Force-Sensitive Resistors (FSRs)**:
  - **Heel FSR ($F_{\text{heel}}$)**: Measures vertical ground reaction impact at initial contact and loading response.
  - **Toe / Forefoot FSR ($F_{\text{toe}}$)**: Measures propulsive terminal stance and pre-swing push-off forces.
  - **Sample Rate**: High-frequency streaming up to $50\text{ Hz}$ ($T_s = 20\text{ ms}$).
- **6-Axis Inertial Measurement Unit (MPU-6050)**:
  - 3-axis Accelerometer ($\pm 2\text{g}$ full-scale range; sensitivity $16384\text{ LSB/g}$).
  - 3-axis Gyroscope ($\pm 250^\circ/\text{s}$ full-scale range; sensitivity $131\text{ LSB}/(^\circ/\text{s})$).
- **Embedded Compute**: ESP32 dual-core microcontroller performing onboard analog sampling, edge hysteresis filtering, cross-limb transition clocking, and BLE notification framing.

---

## 2. Sensor Signal Processing & Force Calibration

### 2.1. ADC Count to Ground Reaction Force (kg)
Raw 12-bit analog-to-digital converter (ADC) readings ($0 \le \text{ADC} \le 4095$) from the voltage divider circuit are mapped to calibrated vertical Ground Reaction Force (vGRF) in kilograms ($\text{kg}$):

$$\text{Force}_{\text{kg}} = \max\left(0.0,\; (0.0125 \times \text{ADC}) - 13.75\right)$$

- **Threshold Cutoff**: Below $\text{ADC} \le 1100$, force clamps to $0.0\text{ kg}$, eliminating baseline circuit noise and static insole pre-load.
- **Reference Implementation**: `FsrUtils` in [`lib/fsr_utils.dart`](file:///d:/insoulv1_stitch_ui/insoulv1/lib/fsr_utils.dart) and `QuickGaitMetrics._rawToKg` in [`lib/quick_gait_metrics.dart`](file:///d:/insoulv1_stitch_ui/insoulv1/lib/quick_gait_metrics.dart).

### 2.2. Total Foot Pressure
For each limb (Left $L$ and Right $R$), total instantaneous vertical ground reaction pressure is the superposition of heel and forefoot sensors:

$$F_{\text{total}, L}(t) = F_{\text{heel}, L}(t) + F_{\text{toe}, L}(t)$$
$$F_{\text{total}, R}(t) = F_{\text{heel}, R}(t) + F_{\text{toe}, R}(t)$$

---

## 3. Step Detection & Edge Triggering

Step detection uses a dual-threshold Schmitt trigger (hysteresis) combined with refractory blanking to prevent bounce artifacts and double-counting during stance micro-movements.

### 3.1. Hysteresis State Machine
- **Press Threshold ($T_{\text{press}}$)**: $1800\text{ ADC}$ counts.
- **Release Threshold ($T_{\text{release}}$)**: $1200\text{ ADC}$ counts.

$$\text{State}(t) = \begin{cases} 
\text{Pressed}, & \text{if } \text{ADC}(t) > T_{\text{press}} \land \text{State}(t-1) = \text{Released} \\ 
\text{Released}, & \text{if } \text{ADC}(t) \le T_{\text{release}} \land \text{State}(t-1) = \text{Pressed} \\ 
\text{State}(t-1), & \text{otherwise} 
\end{cases}$$

### 3.2. Refractory Period Blanking
To avoid false triggers during a prolonged loading response, a temporal refractory window is enforced per limb:

$$\Delta t_{\text{foot}} = t_{\text{event}} - t_{\text{last\_step, foot}} \ge 300\text{ ms}$$

### 3.3. Simultaneous Stance / Standing Filter
When a user stands up or shifts weight with both feet in contact:
- If contralateral heel contact occurs within $\Delta t_{\text{bilateral}} \le 150\text{ ms}$ ($\text{simultaneousHeelWindowMs}$), the event is recognized as a static double-stance transition rather than an ambulatory step, and erroneous step increments are rolled back.
- **Reference Implementation**: `GaitProcessor._processFoot` in [`lib/gait_processor.dart`](file:///d:/insoulv1_stitch_ui/insoulv1/lib/gait_processor.dart).

---

## 4. Temporal Gait Parameters

### 4.1. Cross-Limb Step Transitions ($L \to R$ and $R \to L$)
Stride duration of each individual leg remains mechanically coupled during limping; true asymmetric impairment is captured by the temporal difference between contralateral transitions:
- **Left-to-Right Step Time ($\Delta t_{L \to R}$)**: Interval from Left foot initial contact ($t_{L, i}$) to the subsequent Right foot initial contact ($t_{R, i}$).
- **Right-to-Left Step Time ($\Delta t_{R \to L}$)**: Interval from Right foot initial contact ($t_{R, i}$) to the subsequent Left foot initial contact ($t_{L, i+1}$).

$$\overline{\Delta t}_{L \to R} = \frac{1}{N}\sum_{k=1}^N \Delta t_{L \to R, k}, \quad \overline{\Delta t}_{R \to L} = \frac{1}{N}\sum_{k=1}^N \Delta t_{R \to L, k} \quad (N = 5)$$

### 4.2. Mean Stride Time
The total gait cycle (stride) duration:

$$T_{\text{stride}} = \overline{\Delta t}_{L \to R} + \overline{\Delta t}_{R \to L}$$

If transitions are unavailable, stride time is derived from cadence:

$$T_{\text{stride}} = \frac{120\,000}{\text{Cadence}} \quad (\text{ms})$$

### 4.3. Cadence (Steps per Minute)
Over a standard $10\text{ s}$ Quick Gait window:

$$\text{Cadence} = \text{clamp}\left(\text{Total Steps} \times 6,\; 0,\; 220\right)$$

---

## 5. Bilateral Gait Symmetry & Limp Analysis

### 5.1. Gait Symmetry Index (SI) and Symmetry Score
Symmetry index evaluates the percentage deviation between contralateral step transition times:

$$\overline{\Delta t}_{\text{all}} = \frac{\overline{\Delta t}_{L \to R} + \overline{\Delta t}_{R \to L}}{2}$$

$$\text{Symmetry Index (SI)} = \frac{|\overline{\Delta t}_{L \to R} - \overline{\Delta t}_{R \to L}|}{\overline{\Delta t}_{\text{all}}} \times 100\%$$

$$\text{Symmetry Score (\%)} = \text{clamp}\left(100.0 - (\text{SI} \times 0.5),\; 0.0,\; 100.0\right)$$

*A score of $100\%$ indicates perfect bilateral temporal congruence; healthy adult gait typically falls between $92\%\text{--}100\%$.*

### 5.2. Limping & Asymmetry Classification
A clinical limp summary is classified from cross-step delta $\delta = \overline{\Delta t}_{L \to R} - \overline{\Delta t}_{R \to L}$:

$$\text{Limping Summary} = \begin{cases}
\text{"Left Leg Stance Dominant"}, & \text{if } \delta > +40\text{ ms} \\
\text{"Right Leg Stance Dominant"}, & \text{if } \delta < -40\text{ ms} \\
\text{"Good Bilateral Symmetry"}, & \text{if } |\delta| \le 40\text{ ms}
\end{cases}$$

---

## 6. Sub-Phasic Temporal Analysis (Phasogram)

Human gait divides into **Stance Phase** (foot on ground, ~60% of cycle) and **Swing Phase** (foot in air, ~40% of cycle), with periods of **Double Support** (both feet simultaneously in contact, ~20% of cycle).

### 6.1. Continuous Stance Integration (50 Hz Telemetry)
For session sample series where duration $\ge 2.0\text{ s}$ and samples $S_i$:

$$t_{\text{active}, L} = \sum_{i=1}^M \Delta t_i \cdot \mathbb{I}\left(F_{\text{total}, L}(t_i) > 350\text{ ADC}\right)$$
$$t_{\text{active}, R} = \sum_{i=1}^M \Delta t_i \cdot \mathbb{I}\left(F_{\text{total}, R}(t_i) > 350\text{ ADC}\right)$$
$$t_{\text{double}} = \sum_{i=1}^M \Delta t_i \cdot \mathbb{I}\left(F_{\text{total}, L}(t_i) > 350 \land F_{\text{total}, R}(t_i) > 350\right)$$

The sub-phase percentages relative to total session duration $T_{\text{total}}$:

$$\text{Stance}_L\% = \text{clamp}\left(\frac{t_{\text{active}, L}}{T_{\text{total}}} \times 100\%,\; 45\%,\; 75\%\right)$$
$$\text{Stance}_R\% = \text{clamp}\left(\frac{t_{\text{active}, R}}{T_{\text{total}}} \times 100\%,\; 45\%,\; 75\%\right)$$
$$\text{Double Support}\% = \text{clamp}\left(\frac{t_{\text{double}}}{T_{\text{total}}} \times 100\%,\; 12\%,\; 40\%\right)$$

Swing phases are the exact complements:

$$\text{Swing}_L\% = 100\% - \text{Stance}_L\%, \quad \text{Swing}_R\% = 100\% - \text{Stance}_R\%$$

### 6.2. Analytical Fallback Model
If continuous $50\text{ Hz}$ data is sparse, sub-phases are computed from temporal transition asymmetry:

$$\delta_{\%} = \frac{\overline{\Delta t}_{L \to R} - \overline{\Delta t}_{R \to L}}{\overline{\Delta t}_{\text{all}}} \times 5.0$$
$$\text{Stance}_L\% = \text{clamp}\left(60.0 + \delta_{\%},\; 52.0,\; 68.0\right)$$
$$\text{Stance}_R\% = \text{clamp}\left(60.0 - \delta_{\%},\; 52.0,\; 68.0\right)$$

---

## 7. Gait Variability & Dynamic Fall Risk Assessment

### 7.1. Coefficient of Variation (CV%)
Gait cycle variability ($\text{CV}$) quantifies stride-to-stride temporal inconsistency, a recognized clinical biomarker for ataxia and neurological gait deficits:

$$\text{CV}_{\text{gait}}\% = \text{clamp}\left(\frac{|\overline{\Delta t}_{L \to R} - \overline{\Delta t}_{R \to L}|}{T_{\text{stride}}} \times 100\% \times 0.55,\; 1.1\%,\; 9.5\%\right)$$

### 7.2. Fall Risk Stratification
Evaluated across both cycle variability ($\text{CV}$) and prolonged Double Support ($\text{DST}$):

$$\text{Fall Risk Level} = \begin{cases}
\text{"LOW RISK"}, & \text{if } \text{CV} < 2.5\% \land \text{DoubleSupport}\% \le 25.0\% \\
\text{"MODERATE"}, & \text{if } \text{CV} \le 4.5\% \land \text{DoubleSupport}\% \le 30.0\% \\
\text{"HIGH RISK"}, & \text{otherwise}
\end{cases}$$

### 7.3. Mobility Evaluation
$$\text{Mobility Status} = \begin{cases}
\text{"FLUID \& BALANCED"}, & \text{if } \text{Symmetry} \ge 90.0\% \land \text{CV} < 3.0\% \\
\text{"FUNCTIONAL GAIT"}, & \text{if } \text{Symmetry} \ge 80.0\% \\
\text{"COMPENSATION OBSERVED"}, & \text{otherwise}
\end{cases}$$

---

## 8. Biomechanical Waveform Synthesis & vGRF Modeling

When rendering real-time or export charts, human vertical Ground Reaction Force (vGRF) exhibits the characteristic dual-peak M-wave profile (heel strike peak followed by toe push-off propulsion).

### 8.1. Physiological Curve Model
For normalized stance progress $u \in [0.0, 1.0]$, the force profile is modeled by two Gaussian distributions modulated by a sinusoidal boundary window:

$$W(u) = \sin(\pi u)$$

$$\text{Heel Peak}(u) = F_{\text{target}} \times 0.95 \times \exp\left(-\left(\frac{u - 0.22}{0.13}\right)^2\right) \times \left(\frac{W(u)}{0.637}\right)$$

$$\text{Toe Peak}(u) = F_{\text{target}} \times 1.02 \times \exp\left(-\left(\frac{u - 0.72}{0.14}\right)^2\right) \times \left(\frac{W(u)}{0.774}\right)$$

- **Heel Strike Impact**: Occurs at $u = 0.22$ ($22\%$ into stance).
- **Propulsive Push-Off**: Occurs at $u = 0.72$ ($72\%$ into stance).
- **Mid-stance Trough**: Natural unloading dip at $u \approx 0.45\text{--}0.50$.

$$\text{vGRF}_{\text{total}}(u) = \max\left(0.0,\; \text{Heel Peak}(u) + \text{Toe Peak}(u)\right)$$

### 8.2. Bilateral Mirrored Rendering
To provide visual contrast between limbs without overlapping traces:
- **Left Foot**: Plotted upward ($+y$ axis, Emerald Green `#10B981`).
- **Right Foot**: Plotted downward ($-y$ axis, Amber-Orange `#FB923C`).

### 8.3. 5-Point Gaussian Smoothing Filter
To remove $50\text{ Hz}$ discretization jitter while preserving peak ground reaction impulse:

$$y_i^* = 0.06\,y_{i-2} + 0.24\,y_{i-1} + 0.40\,y_i + 0.24\,y_{i+1} + 0.06\,y_{i+2}$$

- **Reference Implementation**: [`lib/physio_screen.dart`](file:///d:/insoulv1_stitch_ui/insoulv1/lib/physio_screen.dart) and [`lib/gait_waveform_renderer.dart`](file:///d:/insoulv1_stitch_ui/insoulv1/lib/gait_waveform_renderer.dart).

---

## 9. IMU Kinematics & Tilt Tracking

### 9.1. Accelerometer and Gyroscope Scale Factor Conversion
From raw 16-bit signed registers of the MPU-6050:

$$a_x = \frac{\text{raw}_{Ax}}{16384.0}\text{ g}, \quad a_y = \frac{\text{raw}_{Ay}}{16384.0}\text{ g}, \quad a_z = \frac{\text{raw}_{Az}}{16384.0}\text{ g}$$

$$\omega_x = \frac{\text{raw}_{Gx}}{131.0}\;^{\circ}/\text{s}, \quad \omega_y = \frac{\text{raw}_{Gy}}{131.0}\;^{\circ}/\text{s}, \quad \omega_z = \frac{\text{raw}_{Gz}}{131.0}\;^{\circ}/\text{s}$$

### 9.2. Pitch Angle & Dynamic Foot Tilt (Calf Raise / Incline)
Foot tilt angle $\theta_{\text{pitch}}$ relative to gravity is computed via 2-axis arc-tangent:

$$\theta_{\text{pitch}} = \text{atan2}\left(a_x,\; \sqrt{a_y^2 + a_z^2}\right) \times \frac{180^\circ}{\pi}$$

The normalized control deflection:

$$y_{\text{tilt}} = \text{clamp}\left(\frac{\theta_{\text{pitch}}}{45.0^\circ},\; -1.0,\; 1.0\right)$$

An exponential moving average (EMA) filter smoothens the player curve:

$$\bar{y}_{\text{tilt}}(t) = \bar{y}_{\text{tilt}}(t-1) + 0.18 \times \left(y_{\text{tilt}}(t) - \bar{y}_{\text{tilt}}(t-1)\right)$$

- **Reference Implementation**: `_updateGame` in [`lib/calf_raises_minigame.dart`](file:///d:/insoulv1_stitch_ui/insoulv1/lib/calf_raises_minigame.dart).

### 9.3. Dynamic Toe-Standing & Calf Raise Detection
Toe-standing / plantarflexion exercise condition is met when forefoot pressure is active with heels completely unloaded:

$$\text{ToeStandingActive} = (F_{\text{toe}, L} > T_{\text{press}} \lor F_{\text{toe}, R} > T_{\text{press}}) \land (F_{\text{heel}, L} \le T_{\text{release}} \land F_{\text{heel}, R} \le T_{\text{release}})$$

---

## 10. Summary Table of Formulas & Constants

| Biomechanical Metric | Mathematical Formula | Normal Reference Range | Units |
|---|---|---|---|
| **FSR to Force** | $\text{Force} = \max(0, 0.0125 \times \text{ADC} - 13.75)$ | Body weight proportional | $\text{kg}$ |
| **Cadence** | $\text{Total Steps}_{10s} \times 6$ | $90 - 120$ | $\text{steps/min}$ |
| **Stride Time** | $\overline{\Delta t}_{L \to R} + \overline{\Delta t}_{R \to L}$ | $1000 - 1200$ | $\text{ms}$ |
| **Symmetry Index (SI)** | $\frac{\|\overline{\Delta t}_{L \to R} - \overline{\Delta t}_{R \to L}\|}{\text{mean}} \times 100\%$ | $< 6.0\%$ | $\%$ |
| **Symmetry Score** | $\text{clamp}(100 - (\text{SI} \times 0.5), 0, 100)$ | $> 90.0\%$ | $\%$ |
| **Stance Phase %** | $\frac{t_{\text{loaded}}}{t_{\text{total}}} \times 100\%$ | $58\% - 62\%$ | $\%$ |
| **Swing Phase %** | $100\% - \text{Stance}\%$ | $38\% - 42\%$ | $\%$ |
| **Double Support %** | $\frac{t_{\text{both loaded}}}{t_{\text{total}}} \times 100\%$ | $18\% - 24\%$ | $\%$ |
| **Gait Variability (CV)** | $\frac{\|\Delta t_{L \to R} - \Delta t_{R \to L}\|}{T_{\text{stride}}} \times 55$ | $< 2.5\%$ | $\%$ |
| **A/P Roll Time** | Heel-to-toe strike progression | $140 - 180$ | $\text{ms}$ |
| **Foot Pitch Tilt** | $\text{atan2}(a_x, \sqrt{a_y^2 + a_z^2}) \times \frac{180}{\pi}$ | $-45^\circ \text{ to } +45^\circ$ | Degrees |
