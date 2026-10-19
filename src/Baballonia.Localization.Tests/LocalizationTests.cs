using Baballonia.Assets;
using Baballonia.Models;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using System.Collections;
using System.Globalization;
using System.Linq;
using System.Text.RegularExpressions;

namespace Baballonia.Localization.Tests;

[TestClass]
[DoNotParallelize]
public class LocalizationTests
{
    [TestMethod]
    [DataRow("zh-CN")]
    [DataRow("zh-TW")]
    public void ChineseResourcesAreCompleteAndPreserveFormatArguments(string language)
    {
        var neutral = Resources.ResourceManager.GetResourceSet(CultureInfo.InvariantCulture, true, false)!;
        var localized = Resources.ResourceManager.GetResourceSet(new CultureInfo(language), true, false);
        Assert.IsNotNull(localized, $"Missing {language} satellite resources");
        var originals = neutral.Cast<DictionaryEntry>().ToDictionary(x => (string)x.Key, x => (string)x.Value!);
        var translations = localized.Cast<DictionaryEntry>().ToDictionary(x => (string)x.Key, x => (string)x.Value!);
        CollectionAssert.AreEquivalent(originals.Keys.ToArray(), translations.Keys.ToArray());

        foreach (var (key, original) in originals)
        {
            var translation = translations[key];
            Assert.IsFalse(string.IsNullOrWhiteSpace(translation), $"{language}: {key}");
            static string[] Arguments(string value) => Regex.Matches(value, @"\{\d+(?:[^}]*)\}")
                .Select(match => match.Value).OrderBy(value => value).ToArray();
            CollectionAssert.AreEqual(Arguments(original), Arguments(translation), $"{language}: {key}");

            if (key.StartsWith("Calibration_Expression_"))
                Assert.IsTrue(Regex.IsMatch(translation, @"[\p{IsCJKUnifiedIdeographs}]"),
                    $"{language}: untranslated expression {key}");
        }
    }

    [TestMethod]
    public void LocalizedActionsKeepCalibrationKeysAndThresholdsStable()
    {
        var previous = Resources.Culture;
        try
        {
            var resources = Resources.ResourceManager.GetResourceSet(CultureInfo.InvariantCulture, true, false)!;
            var keys = resources.Cast<DictionaryEntry>().Select(x => (string)x.Key)
                .Where(key => key.StartsWith("Calibration_Expression_") && !key.EndsWith("_Description"));
            foreach (var key in keys)
            {
                var parameter = key["Calibration_Expression_".Length..];
                var setting = new SliderBindableSetting(parameter, lower: 0.2f, upper: 0.8f);
                foreach (var language in new[] { "en-US", "zh-CN", "zh-TW" })
                {
                    Resources.Culture = new CultureInfo(language);
                    Assert.AreNotEqual(parameter, setting.DisplayName, $"{language}: {parameter}");
                    Assert.IsFalse(string.IsNullOrWhiteSpace(setting.Description), $"{language}: {parameter}");
                    Assert.AreEqual(parameter, setting.Name);
                    Assert.AreEqual(0.2f, setting.Lower);
                    Assert.AreEqual(0.8f, setting.Upper);
                }
            }

            Resources.Culture = new CultureInfo("zh-CN");
            Assert.AreNotEqual(new SliderBindableSetting("MouthFunnel").DisplayName,
                new SliderBindableSetting("MouthPucker").DisplayName);
            Assert.AreNotEqual(new SliderBindableSetting("JawOpen").DisplayName,
                new SliderBindableSetting("MouthClose").DisplayName);
        }
        finally
        {
            Resources.Culture = previous;
        }
    }
}
