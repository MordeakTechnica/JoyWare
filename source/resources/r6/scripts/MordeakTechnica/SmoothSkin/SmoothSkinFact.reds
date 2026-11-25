module MordeakTechnica

public class SmoothSkinFact {

  public static func GetTierFromTDBID(tdbid: TweakDBID) -> Int32 {
    let tiers: array<TweakDBID> = [
      t"SmoothSkin.SmoothSkinCommon",              // 1
      t"SmoothSkin.SmoothSkinCommonPlus",          // 2
      t"SmoothSkin.SmoothSkinUncommon",            // 3
      t"SmoothSkin.SmoothSkinUncommonPlus",        // 4
      t"SmoothSkin.SmoothSkinRare",                // 5
      t"SmoothSkin.SmoothSkinRarePlus",            // 6
      t"SmoothSkin.SmoothSkinEpic",                // 7
      t"SmoothSkin.SmoothSkinEpicPlus",            // 8
      t"SmoothSkin.SmoothSkinLegendary",           // 9
      t"SmoothSkin.SmoothSkinLegendaryPlus",       // 10
      t"SmoothSkin.SmoothSkinLegendaryPlusPlus"    // 11
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
      let equippedItem: ItemID = eqData.FindItemInEquipAreaByTag(n"MordeakTechnica.SmoothSkin", gamedataEquipmentArea.IntegumentarySystemCW);
      if ItemID.IsValid(equippedItem) {
        return SmoothSkinFact.GetTierFromTDBID(ItemID.GetTDBID(equippedItem));
      }
      let activeItem: ItemID = eqData.GetActiveItem(gamedataEquipmentArea.IntegumentarySystemCW);
      if ItemID.IsValid(activeItem) {
        return SmoothSkinFact.GetTierFromTDBID(ItemID.GetTDBID(activeItem));
      }
    }

    return 0;
  }

  public static func SetFactExplicit(player: ref<PlayerPuppet>, tier: Int32, opt factName: CName) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    if !IsNameValid(factName) {
      factName = n"na_smoothskin_tier";
    }

    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(player.GetGame());
    if IsDefined(questsSystem) {
      questsSystem.SetFact(factName, tier);
      if questsSystem.GetFact(n"smoothskin_debug") > 0 || questsSystem.GetFact(n"mordeak_debug") > 0 {
        FTLog(s"[SmoothSkin] Fact '\(factName)' set to tier: \(tier)");
      }
    }

    return tier;
  }

  public static func SetFact(player: ref<PlayerPuppet>, opt factName: CName) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    let tier: Int32 = SmoothSkinFact.GetTier(player);
    return SmoothSkinFact.SetFactExplicit(player, tier, factName);
  }
}

// -----------------------------------------------------------------------------
// PlayerPuppet Helper Extensions
// -----------------------------------------------------------------------------

@addMethod(PlayerPuppet)
public func GetSmoothSkinTier() -> Int32 {
  return SmoothSkinFact.GetTier(this);
}

@addMethod(PlayerPuppet)
public func SetSmoothSkinFact(opt factName: CName) -> Int32 {
  return SmoothSkinFact.SetFact(this, factName);
}

@addMethod(PlayerPuppet)
public func SetSmoothSkinDebug() -> Void {
  this.SetSmoothSkinDebug(true);
}

@addMethod(PlayerPuppet)
public func SetSmoothSkinDebug(enable: Bool) -> Void {
  let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  if IsDefined(questsSystem) {
    questsSystem.SetFact(n"smoothskin_debug", enable ? 1 : 0);
  }
}

@addMethod(PlayerPuppet)
public func GetSmoothSkinDebug() -> Bool {
  let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.GetGame());
  return IsDefined(questsSystem) && (questsSystem.GetFact(n"smoothskin_debug") > 0 || questsSystem.GetFact(n"mordeak_debug") > 0);
}
