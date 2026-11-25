module MordeakTechnica

public class DollChipFact {

  public static func GetTierFromTDBID(tdbid: TweakDBID) -> Int32 {
    if tdbid == t"DollChip.DollChip" {
      return 1;
    }

    let tiers: array<TweakDBID> = [
      t"DollChip.DollChipCommon",
      t"DollChip.DollChipCommonPlus",
      t"DollChip.DollChipUncommon",
      t"DollChip.DollChipUncommonPlus",
      t"DollChip.DollChipRare",
      t"DollChip.DollChipRarePlus",
      t"DollChip.DollChipEpic",
      t"DollChip.DollChipEpicPlus",
      t"DollChip.DollChipLegendary",
      t"DollChip.DollChipLegendaryPlus",
      t"DollChip.DollChipLegendaryPlusPlus"
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
      let slotCount: Int32 = eqData.GetNumberOfSlots(gamedataEquipmentArea.SystemReplacementCW, true);
      let slotIndex: Int32 = 0;
      while slotIndex < slotCount {
        let equippedItem: ItemID = eqData.GetItemInEquipSlot(gamedataEquipmentArea.SystemReplacementCW, slotIndex);
        if ItemID.IsValid(equippedItem) {
          let tier: Int32 = DollChipFact.GetTierFromTDBID(ItemID.GetTDBID(equippedItem));
          if tier > 0 {
            return tier;
          }
        }
        slotIndex += 1;
      }
    }

    return 0;
  }

  public static func GetPointsForTier(tier: Int32) -> Int32 {
    let pointsByTier: array<Int32> = [0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6];
    if tier < 0 || tier >= ArraySize(pointsByTier) {
      return 0;
    }

    return pointsByTier[tier];
  }

  public static func AwardPoints(player: ref<PlayerPuppet>, tier: Int32) -> Void {
    if !IsDefined(player) {
      return;
    }

    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(player.GetGame());
    if !IsDefined(questsSystem) {
      return;
    }

    let highestAwardedTier: Int32 = questsSystem.GetFact(n"na_dollchip_highest_tier");
    if tier <= highestAwardedTier {
      return;
    }

    let playerDevelopmentData: ref<PlayerDevelopmentData> = PlayerDevelopmentSystem.GetData(player);
    if !IsDefined(playerDevelopmentData) {
      return;
    }

    let previousPoints: Int32 = DollChipFact.GetPointsForTier(highestAwardedTier);
    let currentPoints: Int32 = DollChipFact.GetPointsForTier(tier);
    let pointsToAward: Int32 = currentPoints - previousPoints;
    if pointsToAward > 0 {
      playerDevelopmentData.AddDevelopmentPoints(pointsToAward, gamedataDevelopmentPointType.Secondary);
      playerDevelopmentData.AddDevelopmentPoints(pointsToAward, gamedataDevelopmentPointType.Primary);
    }

    questsSystem.SetFact(n"na_dollchip_highest_tier", tier);
  }

  public static func SetFact(player: ref<PlayerPuppet>) -> Int32 {
    if !IsDefined(player) {
      return 0;
    }

    let tier: Int32 = DollChipFact.GetTier(player);
    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(player.GetGame());
    if IsDefined(questsSystem) {
      questsSystem.SetFact(n"na_dollchip_equipped", tier > 0 ? 1 : 0);
    }

    if tier > 0 {
      DollChipFact.AwardPoints(player, tier);
    }

    return tier;
  }
}

@addMethod(PlayerPuppet)
public func IsDollChipEquipped() -> Bool {
  return DollChipFact.GetTier(this) > 0;
}
