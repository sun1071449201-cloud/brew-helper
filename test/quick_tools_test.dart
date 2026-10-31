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
