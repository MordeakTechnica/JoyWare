module MordeakTechnica

public class RawDogFact {

  public static func GetTierFromTDBID(tdbid: TweakDBID) -> Int32 {
    let tiers: array<TweakDBID> = [
      t"RawDog.RawDogCommon",              // 1
      t"RawDog.RawDogCommonPlus",          // 2
      t"RawDog.RawDogUncommon",            // 3
      t"RawDog.RawDogUncommonPlus",        // 4
      t"RawDog.RawDogRare",                // 5
      t"RawDog.RawDogRarePlus",            // 6
      t"RawDog.RawDogEpic",                // 7
      t"RawDog.RawDogEpicPlus",            // 8
      t"RawDog.RawDogLegendary",           // 9
      t"RawDog.RawDogLegendaryPlus",       // 10
      t"RawDog.RawDogLegendaryPlusPlus"    // 11
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
      let equippedItem: ItemID = eqData.FindItemInEquipAreaByTag(n"NA.RawDog", gamedataEquipmentArea.CardiovascularSystemCW);
      if ItemID.IsValid(equippedItem) {
        return RawDogFact.GetTierFromTDBID(ItemID.GetTDBID(equippedItem));
      }
      let activeItem: ItemID = eqData.GetActiveItem(gamedataEquipmentArea.CardiovascularSystemCW);
      if ItemID.IsValid(activeItem) {
        return RawDogFact.GetTierFromTDBID(ItemID.GetTDBID(activeItem));
      }
    }

    return 0;
  }

  public static func SetFactExplicit(player: ref<PlayerPuppet>, tier: Int32, opt factName: CName) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    if !IsNameValid(factName) {
      factName = n"na_rawdog_tier";
    }

    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(player.GetGame());
    if IsDefined(questsSystem) {
      questsSystem.SetFact(factName, tier);
      if questsSystem.GetFact(n"rawdog_debug") > 0 || questsSystem.GetFact(n"mordeak_debug") > 0 {
        FTLog(s"[RawDog] Fact '\(factName)' set to tier: \(tier)");
      }
    }

    return tier;
  }

  public static func SetFact(player: ref<PlayerPuppet>, opt factName: CName) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    let tier: Int32 = RawDogFact.GetTier(player);
    return RawDogFact.SetFactExplicit(player, tier, factName);
  }
}

// -----------------------------------------------------------------------------
// PlayerPuppet Helper Extensions
// -----------------------------------------------------------------------------

@addMethod(PlayerPuppet)
public func GetRawDogTier() -> Int32 {
  return RawDogFact.GetTier(this);
}

@addMethod(PlayerPuppet)
public func SetRawDogFact(opt factName: CName) -> Int32 {
  return RawDogFact.SetFact(this, factName);
}

@addMethod(PlayerPuppet)
public func SetRawDogDebug() -> Void {
  this.SetRawDogDebug(true);
}

@addMethod(PlayerPuppet)
public func SetRawDogDebug(enable: Bool) -> Void {
  let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  if IsDefined(questsSystem) {
    questsSystem.SetFact(n"rawdog_debug", enable ? 1 : 0);
  }
}

@addMethod(PlayerPuppet)
public func GetRawDogDebug() -> Bool {
  let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  return IsDefined(questsSystem) && (questsSystem.GetFact(n"rawdog_debug") > 0 || questsSystem.GetFact(n"mordeak_debug") > 0);
}
