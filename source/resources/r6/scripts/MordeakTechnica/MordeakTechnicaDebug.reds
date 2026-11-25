module MordeakTechnica

public class MordeakDebug {

  public static func SetAllDebug(player: ref<PlayerPuppet>, enable: Bool) -> Void {
    if !IsDefined(player) {
      return;
    }
    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(player.GetGame());
    if IsDefined(questsSystem) {
      let val: Int32 = enable ? 1 : 0;
      questsSystem.SetFact(n"mordeak_debug", val);
      questsSystem.SetFact(n"rawdog_debug", val);
      questsSystem.SetFact(n"velvettouch_debug", val);
      questsSystem.SetFact(n"smoothskin_debug", val);
      questsSystem.SetFact(n"neverlock_debug", val);
      questsSystem.SetFact(n"dollchip_debug", val);
      FTLog(s"[MordeakTechnica] All cyberware debug logging set to: \(enable)");
    }
  }

  public static func GetAllDebug(player: ref<PlayerPuppet>) -> Bool {
    if !IsDefined(player) {
      return false;
    }
    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(player.GetGame());
    return IsDefined(questsSystem) && questsSystem.GetFact(n"mordeak_debug") > 0;
  }
}

// Global suite debug methods on PlayerPuppet
@addMethod(PlayerPuppet)
public func SetMordeakDebug() -> Void {
  MordeakDebug.SetAllDebug(this, true);
}

@addMethod(PlayerPuppet)
public func SetMordeakDebug(enable: Bool) -> Void {
  MordeakDebug.SetAllDebug(this, enable);
}

@addMethod(PlayerPuppet)
public func GetMordeakDebug() -> Bool {
  return MordeakDebug.GetAllDebug(this);
}

@addMethod(PlayerPuppet)
public func SetCyberwareDebug() -> Void {
  MordeakDebug.SetAllDebug(this, true);
}

@addMethod(PlayerPuppet)
public func SetCyberwareDebug(enable: Bool) -> Void {
  MordeakDebug.SetAllDebug(this, enable);
}

@addMethod(PlayerPuppet)
public func GetCyberwareDebug() -> Bool {
  return MordeakDebug.GetAllDebug(this);
}
