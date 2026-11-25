module CyberwareEx.Customization

import CyberwareEx.*

public abstract class UserConfig {
  public static func SlotExpansions() -> array<ExpansionArea> {
    // Keep Cyberware-EX's mode-specific expansions, placing the new slot first among extra OS slots.
    let expansions: array<ExpansionArea> = DefaultConfig.SlotExpansions();
    let i: Int32 = 0;
    while i < ArraySize(expansions) {
      if Equals(expansions[i].equipmentArea, gamedataEquipmentArea.SystemReplacementCW) {
        let expansion: ExpansionArea = expansions[i];
        // Intelligence_Central_Milestone_1 is Optimization.
        ArrayInsert(expansion.extraSlots, 0, ExpansionSlot.Create(gamedataNewPerkType.Intelligence_Central_Milestone_1, 1));
        expansions[i] = expansion;
        return expansions;
      }
      i += 1;
    }

    // Add the OS area if the default configuration did not include it.
    let slots: array<ExpansionSlot>;
    ArrayPush(slots, ExpansionSlot.Create(gamedataNewPerkType.Intelligence_Central_Milestone_1, 1));
    ArrayPush(expansions, ExpansionArea.Create(gamedataEquipmentArea.SystemReplacementCW, slots));
    return expansions;
  }

  public static func SlotOverrides() -> array<OverrideArea> = DefaultConfig.SlotOverrides()
  public static func UpgradePrice() -> Int32 = DefaultConfig.UpgradePrice()
  public static func ResetPrice() -> Int32 = DefaultConfig.ResetPrice()
  public static func CombinedAbilityMode() -> Bool = DefaultConfig.CombinedAbilityMode()
}
