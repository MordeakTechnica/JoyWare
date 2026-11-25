module MordeakTechnica

public class NeverLockFact {

  public static func GetTierFromTDBID(tdbid: TweakDBID) -> Int32 {
    let tiers: array<TweakDBID> = [
      t"NeverLock.NeverLockCommon",              // 1
      t"NeverLock.NeverLockCommonPlus",          // 2
      t"NeverLock.NeverLockUncommon",            // 3
      t"NeverLock.NeverLockUncommonPlus",        // 4
      t"NeverLock.NeverLockRare",                // 5
      t"NeverLock.NeverLockRarePlus",            // 6
      t"NeverLock.NeverLockEpic",                // 7
      t"NeverLock.NeverLockEpicPlus",            // 8
      t"NeverLock.NeverLockLegendary",           // 9
      t"NeverLock.NeverLockLegendaryPlus",       // 10
      t"NeverLock.NeverLockLegendaryPlusPlus"    // 11
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
      let equippedItem: ItemID = eqData.FindItemInEquipAreaByTag(n"MordeakTechnica.NeverLock", gamedataEquipmentArea.EyesCW);
      if ItemID.IsValid(equippedItem) {
        return NeverLockFact.GetTierFromTDBID(ItemID.GetTDBID(equippedItem));
      }
      let activeItem: ItemID = eqData.GetActiveItem(gamedataEquipmentArea.EyesCW);
      if ItemID.IsValid(activeItem) {
        return NeverLockFact.GetTierFromTDBID(ItemID.GetTDBID(activeItem));
      }
    }

    return 0;
  }

  public static func SetFactExplicit(player: ref<PlayerPuppet>, tier: Int32, opt factName: CName) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    if !IsNameValid(factName) {
      factName = n"na_neverlock_tier";
    }

    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(player.GetGame());
    if IsDefined(questsSystem) {
      questsSystem.SetFact(factName, tier);
      if questsSystem.GetFact(n"neverlock_debug") > 0 || questsSystem.GetFact(n"mordeak_debug") > 0 {
        FTLog(s"[NeverLock] Fact '\(factName)' set to tier: \(tier)");
      }
    }

    return tier;
  }

  public static func SetFact(player: ref<PlayerPuppet>, opt factName: CName) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    let tier: Int32 = NeverLockFact.GetTier(player);
    return NeverLockFact.SetFactExplicit(player, tier, factName);
  }
}

// -----------------------------------------------------------------------------
// PlayerPuppet Helper Extensions
// -----------------------------------------------------------------------------

@addMethod(PlayerPuppet)
public func GetNeverLockTier() -> Int32 {
  return NeverLockFact.GetTier(this);
}

@addMethod(PlayerPuppet)
public func SetNeverLockFact(opt factName: CName) -> Int32 {
  return NeverLockFact.SetFact(this, factName);
}

@addMethod(PlayerPuppet)
public func SetNeverLockDebug() -> Void {
  this.SetNeverLockDebug(true);
}

@addMethod(PlayerPuppet)
public func SetNeverLockDebug(enable: Bool) -> Void {
  let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  if IsDefined(questsSystem) {
    questsSystem.SetFact(n"neverlock_debug", enable ? 1 : 0);
  }
}

@addMethod(PlayerPuppet)
public func GetNeverLockDebug() -> Bool {
  let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  return IsDefined(questsSystem) && (questsSystem.GetFact(n"neverlock_debug") > 0 || questsSystem.GetFact(n"mordeak_debug") > 0);
}
