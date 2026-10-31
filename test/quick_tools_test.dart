import 'package:flutter_test/flutter_test.dart';
import 'package:brew_helper/domain/services/quick_tools.dart';

/// 计算器期望值全部按公式重算（算式写在注释里），禁止心算。
void main() {
  group('比重换算 SG/GU/°P', () {
    test('sgToGu / guToSg', () {
      expect(QuickTools.sgToGu(1.048), closeTo(48.0, 0.01));
      expect(QuickTools.guToSg(48), closeTo(1.048, 0.0001));
    });

    test('sgToPlato: ASBC 多项式', () {
      // -616.868 + 1111.14×1.048 − 630.272×1.048² + 135.997×1.048³
      // = -616.868 + 1164.47472 - 692.2303 + 156.53562 = 11.9120
      expect(QuickTools.sgToPlato(1.048), closeTo(11.912, 0.01));
    });

    test('platoToSg: Balling 近似（与上式互逆）', () {
      // SG = 1 + 12/(258.6 - (12/258.2)×227.1) = 1 + 12/248.0451 = 1.048379
      expect(QuickTools.platoToSg(12), closeTo(1.0484, 0.0005));
    });
  });

  group('ABV 与发酵度', () {
    test('abvSimple: (1.048-1.010)×131.25 = 4.9875', () {
      expect(QuickTools.abvSimple(1.048, 1.010), closeTo(4.99, 0.01));
    });

    test('abvAlternate: 76.08×0.038/0.727 × (1.010/0.794) = 5.0583', () {
      expect(QuickTools.abvAlternate(1.048, 1.010), closeTo(5.06, 0.02));
    });

    test('表观/真发酵度', () {
      // OE = sgToPlato(1.048) = 11.9120；AE = sgToPlato(1.010) = 2.5609
      // AA = (11.9120-2.5609)/11.9120 = 78.50%
      // RE = 0.1808×11.9120 + 0.8192×2.5609 = 4.2516
      // RA = (11.9120-4.2516)/11.9120 = 64.30%
      expect(QuickTools.apparentAttenuation(1.048, 1.010), closeTo(78.5, 0.2));
      expect(QuickTools.realAttenuation(1.048, 1.010), closeTo(64.3, 0.2));
    });
  });

  group('IBU（Tinseth）', () {
    test('利用率 1.050 SG / 60 min ≈ 0.2307', () {
      // bigness = 1.65×0.000125^0.05 = 1.65×0.638036 = 1.052759
      // time = (1-e^-2.4)/4.15 = 0.2191053
      // util = 1.052759×0.2191053 = 0.2306648
      expect(QuickTools.tinsethUtilization(1.050, 60), closeTo(0.2307, 0.001));
    });

    test('30g 10%AA 20L: mg/L=150, IBU=150×0.2306648=34.60', () {
      expect(
        QuickTools.ibuTinseth(
            aaPercent: 10, grams: 30, liters: 20, sg: 1.050, minutes: 60),
        closeTo(34.6, 0.2),
      );
    });

    test('30g 10%AA 100L: mg/L=30, IBU=6.92', () {
      expect(
        QuickTools.ibuTinseth(
            aaPercent: 10, grams: 30, liters: 100, sg: 1.050, minutes: 60),
        closeTo(6.92, 0.05),
      );
    });
  });

  group('清洗剂配比', () {
    test('直接投加: 2% × 100L = 2 kg', () {
      expect(QuickTools.doseMassKg(targetPct: 2, liters: 100), closeTo(2.0, 0.001));
    });

    test('稀释 C1V1=C2V2: 50% 原液配 2%×100L → 4L', () {
      expect(
        QuickTools.concentrateVolumeL(stockPct: 50, targetPct: 2, finalLiters: 100),
        closeTo(4.0, 0.001),
      );
    });
  });

  group('ppm/mg/L/%', () {
    test('定义换算', () {
      expect(QuickTools.ppmToPercent(500), closeTo(0.05, 0.000001));
      expect(QuickTools.percentToPpm(0.05), closeTo(500, 0.000001));
    });

    test('密度修正', () {
      // 500 ppm × 1.05 g/mL = 525 mg/L；反算 525/1.05 = 500
      expect(QuickTools.ppmToMgPerL(500, densityGPerMl: 1.05), closeTo(525, 0.001));
      expect(QuickTools.mgPerLToPpm(525, densityGPerMl: 1.05), closeTo(500, 0.001));
    });
  });

  group('补糖', () {
    test('蔗糖: (2.5-1.2)×100×3.818 = 496.34 g', () {
      expect(
        QuickTools.primingSugarGrams(
            targetVol: 2.5, residualVol: 1.2, liters: 100, kind: SugarKind.sucrose),
        closeTo(496.34, 0.5),
      );
    });

    test('一水葡萄糖: 1.3×100×4.421 = 574.73 g', () {
      expect(
        QuickTools.primingSugarGrams(
            targetVol: 2.5,
            residualVol: 1.2,
            liters: 100,
            kind: SugarKind.dextroseMonohydrate),
        closeTo(574.73, 0.5),
      );
    });

    test('目标低于残余时不给负数', () {
      expect(
        QuickTools.primingSugarGrams(
            targetVol: 1.0, residualVol: 1.5, liters: 100, kind: SugarKind.sucrose),
        0,
      );
    });
  });

  group('糖化水温', () {
    test('投料水温: (0.2/3)×(66-20)+66 = 69.067', () {
      expect(
        QuickTools.strikeWaterTemp(grainTempC: 20, targetMashC: 66, ratioLPerKg: 3.0),
        closeTo(69.07, 0.01),
      );
    });

    test('升温补水: 6×(0.2×25+75)/(95-66) = 480/29 = 16.552', () {
      expect(
        QuickTools.hotWaterKg(
            grainKg: 25, waterL: 75, currentC: 60, targetC: 66, hotC: 95),
        closeTo(16.55, 0.01),
      );
    });

    test('热水温不高于目标时返回 0（不给负数）', () {
      expect(
        QuickTools.hotWaterKg(
            grainKg: 25, waterL: 75, currentC: 60, targetC: 66, hotC: 65),
        0,
      );
    });
  });

  group('水离子（盐添加贡献）', () {
    test('5g 氯化钙 100L：Ca=13.63、Cl=24.12 ppm', () {
      // Ca: 5 × 0.2726 × 1000 / 100 = 13.63
      // Cl: 5 × 0.4823 × 1000 / 100 = 24.115
      expect(
        QuickTools.ionPpm(grams: 5, liters: 100, fraction: 0.2726),
        closeTo(13.63, 0.01),
      );
      expect(
        QuickTools.ionPpm(grams: 5, liters: 100, fraction: 0.4823),
        closeTo(24.12, 0.01),
      );
    });

    test('反算：目标 Ca 50ppm @100L 氯化钙 → 18.34 g', () {
      // grams = 50 × 100 / (0.2726 × 1000) = 18.3419
      expect(
        QuickTools.ionGrams(ppm: 50, liters: 100, fraction: 0.2726),
        closeTo(18.34, 0.01),
      );
    });
  });

  group('麦芽蛋白质', () {
    test('总氮 1.55% → 蛋白质干基 9.69%', () {
      // 1.55 × 6.25 = 9.6875
      expect(QuickTools.proteinFromNitrogen(1.55), closeTo(9.69, 0.01));
    });

    test('干基 → 风干基（水分 5%）', () {
      // 9.6875 × 0.95 = 9.2031
      expect(QuickTools.proteinDryToAsIs(9.6875, 5), closeTo(9.20, 0.01));
    });

    test('风干基 → 干基（水分 5%）：10 ÷ 0.95 = 10.5263', () {
      expect(QuickTools.proteinAsIsToDry(10.0, 5), closeTo(10.53, 0.01));
    });
  });

  group('分次酒花 IBU 汇总', () {
    test('两次添加（60min + 10min）分别算再相加 = 11.86', () {
      // 第 1 次：AA 12%×30g，100L，1.048，60min
      //   bigness = 1.65×0.000125^0.048 = 1.65×0.649613 = 1.071862
      //   time = (1-e^-2.4)/4.15 = 0.2191053 → util = 0.234852
      //   mg/L = 36 → IBU_A = 8.4547
      // 第 2 次：AA 8%×50g，10min
      //   time = (1-e^-0.4)/4.15 = 0.0794410 → util = 0.0851490
      //   mg/L = 40 → IBU_B = 3.4060
      // 合计 ≈ 11.86
      final total = QuickTools.ibuTotal(
        liters: 100,
        sg: 1.048,
        additions: [
          (aaPercent: 12, grams: 30, minutes: 60),
          (aaPercent: 8, grams: 50, minutes: 10),
        ],
      );
      expect(total, closeTo(11.86, 0.05));
    });

    test('单次添加时 ibuTotal 与 ibuTinseth 一致', () {
      final one = QuickTools.ibuTinseth(
          aaPercent: 10, grams: 30, liters: 20, sg: 1.050, minutes: 60);
      final total = QuickTools.ibuTotal(liters: 20, sg: 1.050, additions: [
        (aaPercent: 10, grams: 30, minutes: 60),
      ]);
      expect(total, closeTo(one, 0.0001));
    });
  });

  group('水硬度 °dH', () {
    test('Ca 40 ppm → 5.60 °dH', () {
      // 40 × 2.4972 / 17.848 = 5.5962
      expect(QuickTools.calciumToDh(40), closeTo(5.60, 0.01));
    });

    test('Mg 10 ppm → 2.31 °dH', () {
      // 10 × 4.1176 / 17.848 = 2.3070
      expect(QuickTools.magnesiumToDh(10), closeTo(2.31, 0.01));
    });

    test('总硬度 = 钙 + 镁', () {
      // 5.5962 + 2.3070 = 7.9032
      expect(
        QuickTools.totalHardnessDh(caPpm: 40, mgPpm: 10),
        closeTo(7.90, 0.01),
      );
    });
  });

  group('糖浆稀释（质量浓度）', () {
    test('100 kg 50% 稀到 10%：加水 400 kg（1:5 稀释）', () {
      // 100 × (50/10 − 1) = 100 × 4 = 400
      expect(
        QuickTools.diluteWaterKg(stockKg: 100, stockPct: 50, targetPct: 10),
        closeTo(400, 0.01),
      );
    });

    test('混合浓度：100kg 50% + 400kg 水沟兑 → 10%', () {
      // (100×50 + 400×0) / 500 = 10
      expect(
        QuickTools.mixPct(m1: 100, c1: 50, m2: 400, c2: 0),
        closeTo(10, 0.001),
      );
    });
  });

  group('CO2 亨利定律', () {
    test('4°C 0.8 bar 表压 ≈ 2.51 vol', () {
      // k_H(4°C) = 0.034×exp(2400×(1/277.15-1/298.15)) = 0.034×1.84009 = 0.062563
      // P_abs = (0.8+1.01325)×0.986923 = 1.789537 atm
      // g/L = 0.062563×44.01×1.789537 = 4.927374；vol = 4.927374/1.9621 = 2.5112
      expect(
        QuickTools.co2Volumes(tempC: 4, pressureBarGauge: 0.8),
        closeTo(2.51, 0.05),
      );
    });

    test('反算: 4°C 2.5 vol → 0.792 bar 表压', () {
      // g/L = 2.5×1.9621 = 4.90525；atm = 4.90525/2.753393 = 1.78191
      // bar_abs = 1.805555；gauge = 0.792305
      expect(
        QuickTools.pressureForVolumes(tempC: 4, volumes: 2.5),
        closeTo(0.79, 0.05),
      );
    });

    test('温度越高同压力下含量越低', () {
      final cold = QuickTools.co2Volumes(tempC: 2, pressureBarGauge: 0.8);
      final warm = QuickTools.co2Volumes(tempC: 10, pressureBarGauge: 0.8);
      expect(warm, lessThan(cold));
    });
  });
}
