module MordeakTechnica

@if(ModuleExists("CyberwareEx"))
import CyberwareEx.*

@if(ModuleExists("CyberwareEx"))
public class DollChipSlot {
  public static func HasItemInExtraSlot(player: ref<PlayerPuppet>) -> Bool {
    if IsOverrideMode() {
      return false;
    }

    // Cyberware-EX generates slot IDs from the area, index, perk and perk level.
    let records: array<TweakDBID> = TweakDBInterface.GetForeignKeyArray(t"EquipmentArea.SystemReplacementCW.equipSlots");
    let index: Int32 = ArraySize(records) - 1;
    while index >= 0 {
      let slotID: TweakDBID = TDBID.Create(s"EquipmentArea.SystemReplacementCW_Slot_\(index)_Perk_Intelligence_Central_Milestone_1_1");
      if records[index] == slotID {
        if !IsDefined(player) {
          FTLog("[MordeakTechnica] Cannot check the extra OS slot before refunding perks: player unavailable.");
          return true;
        }
        let equipment: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
        if !IsDefined(equipment) {
          FTLog("[MordeakTechnica] Cannot check the extra OS slot before refunding perks: equipment unavailable.");
          return true;
        }
        let area: Int32 = equipment.GetEquipAreaIndex(gamedataEquipmentArea.SystemReplacementCW);
        if area < 0 || index >= ArraySize(equipment.m_equipment.equipAreas[area].equipSlots)
          || equipment.m_equipment.equipAreas[area].equipSlots[index].slotID != slotID {
          FTLog("[MordeakTechnica] Cannot check the extra OS slot before refunding perks: slot records do not match equipment.");
          return true;
        }
        return ItemID.IsValid(equipment.GetItemInEquipSlot(gamedataEquipmentArea.SystemReplacementCW, index));
      }
      index -= 1;
    }

    FTLog("[MordeakTechnica] Cannot check the extra OS slot before refunding perks: slot record not found.");
    return true;
  }
}

@if(ModuleExists("CyberwareEx"))
@wrapMethod(PlayerDevelopmentSystem)
public final static func CanSellNewPerk(player: ref<PlayerPuppet>, perkType: gamedataNewPerkType) -> CanSellNewPerkResult {
  let result: CanSellNewPerkResult = wrappedMethod(player, perkType);
  if result.success && Equals(perkType, gamedataNewPerkType.Intelligence_Central_Milestone_1)
    && DollChipSlot.HasItemInExtraSlot(player) {
    result.success = false;
    result.perkType = perkType;
    result.message = "UI-Notifications-RespecCyberwareSlotBlocked";
  }
  return result;
}

@if(ModuleExists("CyberwareEx"))
@wrapMethod(PlayerDevelopmentSystem)
public final static func CanSellNewPerks(player: ref<PlayerPuppet>) -> CanSellNewPerkResult {
  let result: CanSellNewPerkResult = wrappedMethod(player);
  if result.success && DollChipSlot.HasItemInExtraSlot(player) {
    return PlayerDevelopmentSystem.CanSellNewPerk(player, gamedataNewPerkType.Intelligence_Central_Milestone_1);
  }
  return result;
}

@if(ModuleExists("CyberwareEx"))
@wrapMethod(PlayerDevelopmentData)
public final func SellNewPerk(perkType: gamedataNewPerkType, out perkLevelSold: Int32) -> Bool {
  if Equals(perkType, gamedataNewPerkType.Intelligence_Central_Milestone_1) && DollChipSlot.HasItemInExtraSlot(this.m_owner as PlayerPuppet) {
    FTLog("[MordeakTechnica] Empty the extra OS slot before refunding Optimization.");
    perkLevelSold = 0;
    return false;
  }
  return wrappedMethod(perkType, perkLevelSold);
}

@if(ModuleExists("CyberwareEx"))
@wrapMethod(PlayerDevelopmentData)
public final func ForceSellNewPerk(perkType: gamedataNewPerkType, out perkLevelSold: Int32) -> Bool {
  if Equals(perkType, gamedataNewPerkType.Intelligence_Central_Milestone_1) && DollChipSlot.HasItemInExtraSlot(this.m_owner as PlayerPuppet) {
    FTLog("[MordeakTechnica] Empty the extra OS slot before refunding Optimization.");
    perkLevelSold = 0;
    return false;
  }
  return wrappedMethod(perkType, perkLevelSold);
}

@if(ModuleExists("CyberwareEx"))
@wrapMethod(PlayerDevelopmentData)
public final func ResetNewPerks() -> Void {
  if DollChipSlot.HasItemInExtraSlot(this.m_owner as PlayerPuppet) {
    FTLog("[MordeakTechnica] Empty the extra OS slot before resetting perks.");
    return;
  }
  wrappedMethod();
}
