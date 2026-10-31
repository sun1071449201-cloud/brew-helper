import 'dart:math' as math;

/// 酿造计算引擎：全部静态纯函数，便于单测；页面只做输入输出。
/// 所有经验/推导公式都注明出处与适用边界；输出仅供现场参考，
/// 工艺判定一律以本厂 SOP / 工艺卡为准。
class QuickTools {
  QuickTools._();

  // ---------- 比重换算 SG ↔ GU ↔ °P ----------

  /// GU（Gravity Units）：GU = (SG − 1) × 1000。
  static double sgToGu(double sg) => (sg - 1) * 1000;

  /// SG = 1 + GU / 1000。
  static double guToSg(double gu) => 1 + gu / 1000;

  /// SG → °P（ASBCPlato 多项式，SG 1.000~1.100 内误差 <0.05 °P）。
  /// Lincoln, ASBC Methods of Analysis (classic 3rd-order polynomial).
  static double sgToPlato(double sg) =>
      -616.868 + 1111.14 * sg - 630.272 * sg * sg + 135.997 * sg * sg * sg;

  /// °P → SG（Balling 近似式，常与上式互为逆运算使用）。
  /// SG = 1 + P / (258.6 − (P / 258.2) × 227.1)。
  static double platoToSg(double plato) =>
      1 + plato / (258.6 - (plato / 258.2) * 227.1);

  // ---------- 酒精度 ABV 与发酵度 ----------

  /// 简化式：ABV% ≈ (OG − FG) × 131.25（家用/快速估算，±0.5% 量级）。
  static double abvSimple(double og, double fg) => (og - fg) * 131.25;

  /// 精确式：ABV% = (76.08 × (OG − FG) / (1.775 − OG)) × (FG / 0.794)。
  /// 高酒精度下比简化式更准（Ritchie Products Ltd. 常用式）。
  static double abvAlternate(double og, double fg) =>
      (76.08 * (og - fg) / (1.775 - og)) * (fg / 0.794);

  /// 表观发酵度 AA% = (OE − AE) / OE × 100（外观糖度差，含酒精影响，偏大）。
  static double apparentAttenuation(double og, double fg) {
    final oe = sgToPlato(og);
    final ae = sgToPlato(fg);
    if (oe <= 0) return 0;
    return (oe - ae) / oe * 100;
  }

  /// 真发酵度 RA% = (OE − RE) / OE × 100，RE = 0.1808×OE + 0.8192×AE。
  /// 真发酵度扣除了酒精对比重的影响，约为表观发酵度的 82%。
  static double realAttenuation(double og, double fg) {
    final oe = sgToPlato(og);
    final ae = sgToPlato(fg);
    if (oe <= 0) return 0;
    final re = 0.1808 * oe + 0.8192 * ae;
    return (oe - re) / oe * 100;
  }

  // ---------- 酒花苦度 IBU（Tinseth 法） ----------

  /// Tinseth 利用率 = Bigness × Time。
  /// Bigness = 1.65 × 0.000125^(SG − 1)（麦汁浓度越高利用率越低）；
  /// Time = (1 − e^(−0.04 × min)) / 4.15（煮沸时间因子）。
  static double tinsethUtilization(double sg, double minutes) {
    final bigness = 1.65 * math.pow(0.000125, sg - 1).toDouble();
    final timeFactor = (1 - math.exp(-0.04 * minutes)) / 4.15;
    return bigness * timeFactor;
  }

  /// IBU = 甲酸添加浓度(mg/L) × 利用率。
  /// mg/L = AA% × 酒花克数 × 1000 / 麦汁升数。
  static double ibuTinseth({
    required double aaPercent,
    required double grams,
    required double liters,
    required double sg,
    required double minutes,
  }) {
    if (liters <= 0) return 0;
    final mgPerL = aaPercent / 100 * grams * 1000 / liters;
    return mgPerL * tinsethUtilization(sg, minutes);
  }

  /// 分次添加 IBU 汇总：每次添加的利用率差别很大，必须分别算再相加。
  /// additions 用 Record 列表 (aaPercent, grams, minutes)。
  static double ibuTotal({
    required double liters,
    required double sg,
    required List<({double aaPercent, double grams, double minutes})>
        additions,
  }) {
    if (liters <= 0) return 0;
    var sum = 0.0;
    for (final a in additions) {
      sum += ibuTinseth(
        aaPercent: a.aaPercent,
        grams: a.grams,
        liters: liters,
        sg: sg,
        minutes: a.minutes,
      );
    }
    return sum;
  }

  // ---------- 水硬度（°dH 德国度） ----------

  /// 1 °dH = 17.848 mg/L CaCO3 当量（定义换算）。
  static const _mgPerLiterPerDh = 17.848;

  /// Ca²⁺ → CaCO3 当量系数 = 100.09 / 40.078 = 2.4972。
  static double calciumToDh(double caPpm) =>
      caPpm * 2.4972 / _mgPerLiterPerDh;

  /// Mg²⁺ → CaCO3 当量系数 = 100.09 / 24.305 = 4.1176。
  static double magnesiumToDh(double mgPpm) =>
      mgPpm * 4.1176 / _mgPerLiterPerDh;

  /// 总硬度 = 钙硬度 + 镁硬度（°dH）。
  static double totalHardnessDh(
          {required double caPpm, required double mgPpm}) =>
      calciumToDh(caPpm) + magnesiumToDh(mgPpm);

  // ---------- 糖浆稀释（质量浓度） ----------

  /// 质量稀释加水量 kg：加到目标浓度需要补的水
  /// = 原液质量 × (C1/C2 − 1)（质量分数口径）。
  static double diluteWaterKg({
    required double stockKg,
    required double stockPct,
    required double targetPct,
  }) {
    if (targetPct <= 0) return 0;
    return stockKg * (stockPct / targetPct - 1);
  }

  /// 两物料混合后质量浓度：% = (m1×C1 + m2×C2) / (m1+m2)。
  static double mixPct({
    required double m1,
    required double c1,
    required double m2,
    required double c2,
  }) {
    final total = m1 + m2;
    if (total <= 0) return 0;
    return (m1 * c1 + m2 * c2) / total;
  }

  // ---------- 清洗剂配比 ----------

  /// 直接投加：投加量 kg ≈ 目标浓度% / 100 × 配液升数（水的密度按 1 kg/L 计）。
  static double doseMassKg({
    required double targetPct,
    required double liters,
  }) =>
      targetPct / 100 * liters;

  /// 稀释定容（C1V1 = C2V2）：从浓度 C1 的原液取 V1 升，加水中和到 C2、总量 V2。
  static double concentrateVolumeL({
    required double stockPct,
    required double targetPct,
    required double finalLiters,
  }) {
    if (stockPct <= 0) return 0;
    return targetPct * finalLiters / stockPct;
  }

  // ---------- ppm ↔ mg/L ↔ % ----------

  /// 稀溶液（水基）近似：1 ppm = 1 mg/L。
  static double ppmToMgPerL(double ppm, {double densityGPerMl = 1.0}) =>
      densityGPerMl <= 0 ? 0 : ppm * densityGPerMl;

  /// mg/L → ppm（密度修正；清水/麦汁稀溶液密度按 1 计即 1:1）。
  static double mgPerLToPpm(double mgPerL, {double densityGPerMl = 1.0}) =>
      densityGPerMl <= 0 ? 0 : mgPerL / densityGPerMl;

  /// % = ppm / 10000；ppm = % × 10000。
  static double ppmToPercent(double ppm) => ppm / 10000;
  static double percentToPpm(double pct) => pct * 10000;

  // ---------- 补糖（发酵后碳酸化） ----------

  /// 糖的“每升每体积 CO2 需求量”（化学计量推导，20°C STP 换算）：
  /// - 蔗糖 C12H22O11（M=342.30）：1 mol → 4 mol CO2 = 89.656 L → 3.818 g/(L·vol)
  /// - 葡萄糖 C6H12O6（M=180.16）：1 mol → 2 mol CO2 = 44.828 L → 4.019 g/(L·vol)
  /// - 一水葡萄糖 C6H12O6·H2O（M=198.17）：→ 44.828 L → 4.421 g/(L·vol)
  /// 实际溶解度随酒温变化，结果为参考值，以本厂碳酸化工艺卡为准。
  static double gramsPerLiterPerVol(SugarKind kind) => kind.gramsPerLiterPerVol;

  /// 补糖量 g = (目标体积数 − 残余体积数) × 酒量 L × 单位需糖量。
  static double primingSugarGrams({
    required double targetVol,
    required double residualVol,
    required double liters,
    required SugarKind kind,
  }) {
    final delta = (targetVol - residualVol).clamp(0.0, 10.0);
    return delta * liters * kind.gramsPerLiterPerVol;
  }

  // ---------- 糖化水温（热水用量） ----------

  /// 投料水温：Tw = (0.2 / r) × (T2 − T1) + T2。
  /// r = 水粮比 L/kg；0.2 为麦芽相对水的比热（常用经验常数）。
  static double strikeWaterTemp({
    required double grainTempC,
    required double targetMashC,
    required double ratioLPerKg,
  }) {
    if (ratioLPerKg <= 0) return targetMashC;
    return (0.2 / ratioLPerKg) * (targetMashC - grainTempC) + targetMashC;
  }

  /// 升温补加热水量 kg（≈L）：
  /// m = (T2 − T1) × (0.2 × 麦芽kg + 现有水L) / (热水温 − T2)。
  static double hotWaterKg({
    required double grainKg,
    required double waterL,
    required double currentC,
    required double targetC,
    required double hotC,
  }) {
    final denom = hotC - targetC;
    if (denom <= 0) return 0;
    return (targetC - currentC) * (0.2 * grainKg + waterL) / denom;
  }

  // ---------- 酿造水离子（盐添加贡献） ----------

  /// 离子浓度贡献（ppm = mg/L）：
  /// ppm = 盐克数 × 该离子质量分数 × 1000 / 水量升数。
  /// 质量分数由摩尔质量直接算出（定义换算，非经验值）。
  static double ionPpm({
    required double grams,
    required double liters,
    required double fraction,
  }) {
    if (liters <= 0) return 0;
    return grams * fraction * 1000 / liters;
  }

  /// 反算：要达到目标 ppm 需要投的盐克数。
  static double ionGrams({
    required double ppm,
    required double liters,
    required double fraction,
  }) {
    if (fraction <= 0) return 0;
    return ppm * liters / (fraction * 1000);
  }

  // ---------- 麦芽蛋白质 ----------

  /// 蛋白质%（干基）= 总氮% × 6.25（谷物通用 Jones 换算系数）。
  static double proteinFromNitrogen(double nitrogenPct) => nitrogenPct * 6.25;

  /// 干基 → 风干基（as-is）：乘 (1 − 水分%)。
  static double proteinDryToAsIs(double proteinDryPct, double moisturePct) =>
      proteinDryPct * (1 - moisturePct / 100);

  /// 风干基 → 干基：除以 (1 − 水分%)。
  static double proteinAsIsToDry(double proteinAsIsPct, double moisturePct) {
    final f = 1 - moisturePct / 100;
    return f <= 0 ? 0 : proteinAsIsPct / f;
  }

  // ---------- CO2 含量对照（亨利定律） ----------

  /// CO2 在啤酒（近似水）中的亨利常数（mol/(L·atm)），Sander 2015 关联式：
  /// k_H(T) = k_H(298.15) × exp(2400 × (1/T − 1/298.15))，k_H(298.15)=0.034。
  static double _henryMolPerLAtm(double tempC) {
    const k298 = 0.034;
    const c = 2400.0;
    final tK = tempC + 273.15;
    return k298 * math.exp(c * (1 / tK - 1 / 298.15));
  }

  /// 1 体积 CO2 ≈ 1.9621 g/L（STP 摩尔体积换算，行业惯用值）。
  static const _gramsPerLiterPerVol = 1.9621;

  /// 酒温 T °C、表压 P bar 下饱和 CO2 体积数：
  /// V = k_H(T) × 44.01 × P_abs(atm) / 1.9621。
  static double co2Volumes({
    required double tempC,
    required double pressureBarGauge,
  }) {
    final pAtm = (pressureBarGauge + 1.01325) * 0.986923; // bar → atm
    final gramsPerL = _henryMolPerLAtm(tempC) * 44.01 * pAtm;
    return gramsPerL / _gramsPerLiterPerVol;
  }

  /// 反算：酒温 T °C 下达到目标体积数所需表压（bar）。
  static double pressureForVolumes({
    required double tempC,
    required double volumes,
  }) {
    final gramsPerL = volumes * _gramsPerLiterPerVol;
    final k = _henryMolPerLAtm(tempC) * 44.01;
    if (k <= 0) return 0;
    final atm = gramsPerL / k;
    return atm / 0.986923 - 1.01325;
  }
}

/// 补糖用糖种类（见 [QuickTools.gramsPerLiterPerVol] 推导）。
enum SugarKind {
  sucrose('蔗糖/白糖', 3.818),
  glucose('葡萄糖', 4.019),
  dextroseMonohydrate('一水葡萄糖', 4.421);

  const SugarKind(this.label, this.gramsPerLiterPerVol);

  final String label;
  final double gramsPerLiterPerVol;
}
