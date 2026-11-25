module MordeakTechnica

public class VelvetTouchFact {

  public static func GetTierFromTDBID(tdbid: TweakDBID) -> Int32 {
    let tiers: array<TweakDBID> = [
      t"VelvetTouch.VelvetTouchCommon",              // 1
      t"VelvetTouch.VelvetTouchCommonPlus",          // 2
      t"VelvetTouch.VelvetTouchUncommon",            // 3
      t"VelvetTouch.VelvetTouchUncommonPlus",        // 4
      t"VelvetTouch.VelvetTouchRare",                // 5
      t"VelvetTouch.VelvetTouchRarePlus",            // 6
      t"VelvetTouch.VelvetTouchEpic",                // 7
      t"VelvetTouch.VelvetTouchEpicPlus",            // 8
      t"VelvetTouch.VelvetTouchLegendary",           // 9
      t"VelvetTouch.VelvetTouchLegendaryPlus",       // 10
      t"VelvetTouch.VelvetTouchLegendaryPlusPlus"    // 11
    ];

    let index: Int32 = ArrayFindFirst(tiers, tdbid);
    return index >= 0 ? index + 1 : 0;
  }

  public static func GetTier(player: ref<PlayerPuppet>) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    let eqData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(player);
    if IsDefined(eqData) {
      let equippedItem: ItemID = eqData.FindItemInEquipAreaByTag(n"MordeakTechnica.VelvetTouch", gamedataEquipmentArea.HandsCW);
      if ItemID.IsValid(equippedItem) {
        return VelvetTouchFact.GetTierFromTDBID(ItemID.GetTDBID(equippedItem));
      }
      let activeItem: ItemID = eqData.GetActiveItem(gamedataEquipmentArea.HandsCW);
      if ItemID.IsValid(activeItem) {
        return VelvetTouchFact.GetTierFromTDBID(ItemID.GetTDBID(activeItem));
      }
    }

    return 0;
  }

  public static func SetFactExplicit(player: ref<PlayerPuppet>, tier: Int32, opt factName: CName) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    if !IsNameValid(factName) {
      factName = n"na_velvettouch_tier";
    }

    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(player.GetGame());
    if IsDefined(questsSystem) {
      questsSystem.SetFact(factName, tier);
      if questsSystem.GetFact(n"velvettouch_debug") > 0 || questsSystem.GetFact(n"mordeak_debug") > 0 {
        FTLog(s"[VelvetTouch] Fact '\(factName)' set to tier: \(tier)");
      }
    }

    return tier;
  }

  public static func SetFact(player: ref<PlayerPuppet>, opt factName: CName) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    let tier: Int32 = VelvetTouchFact.GetTier(player);
    return VelvetTouchFact.SetFactExplicit(player, tier, factName);
  }
}

// -----------------------------------------------------------------------------
// PlayerPuppet Helper Extensions
// -----------------------------------------------------------------------------

@addMethod(PlayerPuppet)
public func GetVelvetTouchTier() -> Int32 {
  return VelvetTouchFact.GetTier(this);
}

@addMethod(PlayerPuppet)
public func SetVelvetTouchFact(opt factName: CName) -> Int32 {
  return VelvetTouchFact.SetFact(this, factName);
}

@addMethod(PlayerPuppet)
public func SetVelvetTouchDebug() -> Void {
  this.SetVelvetTouchDebug(true);
}

@addMethod(PlayerPuppet)
public func SetVelvetTouchDebug(enable: Bool) -> Void {
  let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  if IsDefined(questsSystem) {
    questsSystem.SetFact(n"velvettouch_debug", enable ? 1 : 0);
  }
}

@addMethod(PlayerPuppet)
public func GetVelvetTouchDebug() -> Bool {
  let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  return IsDefined(questsSystem) && (questsSystem.GetFact(n"velvettouch_debug") > 0 || questsSystem.GetFact(n"mordeak_debug") > 0);
}
