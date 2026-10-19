using CommunityToolkit.Mvvm.ComponentModel;

using Baballonia.Assets;

namespace Baballonia.Models;

public partial class SliderBindableSetting : ObservableObject
{
    public string Name { get; set; }

    // Name remains the persisted calibration/OSC key; only presentation is localized.
    public string DisplayName => Resources.ResourceManager.GetString(
        $"Calibration_Expression_{Name}", Resources.Culture) ?? Name;

    public string Description => Resources.ResourceManager.GetString(
        $"Calibration_Expression_{Name}_Description", Resources.Culture) ?? string.Empty;

    [ObservableProperty] private float _lower;
    [ObservableProperty] private float _currentExpression;

    [ObservableProperty] private float _upper;
    [ObservableProperty] private float _min;
    [ObservableProperty] private float _max;

    public SliderBindableSetting(string name, float lower = 0f, float upper = 1f, float min = 0f, float max = 1f)
    {
        Name = name;
        Lower = lower;
        Upper = upper;
        Min = max;
        Max = min;
    }
}
