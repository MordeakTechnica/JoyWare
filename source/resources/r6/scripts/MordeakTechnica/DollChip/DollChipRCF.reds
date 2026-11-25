module MordeakTechnica

import RedscriptConfigFramework.*
import RedscriptConfigFramework.Api3_2_1.*

public class MordeakDollChipSettingsProvider extends DVRCF_Provider {
  private let m_game: GameInstance;
  private let m_hudColor: Int32;
  private let m_backgroundColor: Int32;
  private let m_backgroundOpacity: Int32;

  public func OnPickerOpen(ctx: ref<DVRCF_PickerContext>) -> Bool {
    if ctx.pregame {
      return false;
    }
    return MordeakDollChipSettingsPopup.Show(ctx.gi, this);
  }

  public func BuildSchema() -> ref<DVRCF_Schema> {
    let colors: array<String>;
    ArrayPush(colors, "Red");
    ArrayPush(colors, "Yellow");
    ArrayPush(colors, "Blue");
    ArrayPush(colors, "Pink");
    ArrayPush(colors, "Black");

    let b: ref<DVRCF_SchemaBuilder> = DVRCF_SchemaBuilder.New("Mordeak Technica");
    b.Tab("DollChip HUD")
      .Section("DollChip HUD")
      .Dropdown("hud_color", "HUD Color", colors)
        .Tip("Choose the DollChip HUD accent color.")
      .Dropdown("background_color", "Background Color", colors)
        .Tip("Choose the main HUD background color.")
      .Stepper("background_opacity", "Background Opacity (%)", 0.0, 100.0, 1.0, true)
        .Tip("Set the main HUD background opacity. 0 is transparent and 100 is opaque.");
    return b.Build();
  }

  public func GetInt(key: String) -> Int32 {
    if Equals(key, "hud_color") {
      return this.m_hudColor;
    }
    if Equals(key, "background_color") {
      return this.m_backgroundColor;
    }
    if Equals(key, "background_opacity") {
      return this.m_backgroundOpacity;
    }
    return 0;
  }

  public func SetInt(key: String, value: Int32) -> Void {
    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.m_game);
    if Equals(key, "hud_color") {
      this.m_hudColor = Clamp(value, 0, 4);
      if IsDefined(questsSystem) {
        questsSystem.SetFact(n"mordeak_dollchip_hud_color", this.m_hudColor + 1);
      }
      return;
    }
    if Equals(key, "background_color") {
      this.m_backgroundColor = Clamp(value, 0, 4);
      if IsDefined(questsSystem) {
        questsSystem.SetFact(n"mordeak_dollchip_hud_background_color", this.m_backgroundColor + 2);
      }
      return;
    }
    if Equals(key, "background_opacity") {
      this.m_backgroundOpacity = Clamp(value, 0, 100);
      if IsDefined(questsSystem) {
        questsSystem.SetFact(n"mordeak_dollchip_hud_opacity", this.m_backgroundOpacity + 1);
      }
    }
  }

  public func OnSettingsRestored() -> Void {
    this.SyncFacts();
  }

  public func OnSave() -> Void {
    this.SyncFacts();
  }

  private func SyncFacts() -> Void {
    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(this.m_game);
    if !IsDefined(questsSystem) {
      return;
    }
    questsSystem.SetFact(n"mordeak_dollchip_hud_color", this.m_hudColor + 1);
    questsSystem.SetFact(n"mordeak_dollchip_hud_background_color", this.m_backgroundColor + 2);
    questsSystem.SetFact(n"mordeak_dollchip_hud_opacity", this.m_backgroundOpacity + 1);
  }

  public func InitializeFromFacts(game: GameInstance) -> Void {
    this.m_game = game;
    let questsSystem: ref<QuestsSystem> = GameInstance.GetQuestsSystem(game);
    if !IsDefined(questsSystem) {
      this.m_hudColor = 0;
      this.m_backgroundColor = 4;
      this.m_backgroundOpacity = 100;
      return;
    }

    let colorFact: Int32 = questsSystem.GetFact(n"mordeak_dollchip_hud_color");
    this.m_hudColor = colorFact >= 1 && colorFact <= 5 ? colorFact - 1 : 0;

    let backgroundFact: Int32 = questsSystem.GetFact(n"mordeak_dollchip_hud_background_color");
    if backgroundFact >= 2 && backgroundFact <= 6 {
      this.m_backgroundColor = backgroundFact - 2;
    } else {
      this.m_backgroundColor = 4;
    }

    let opacityFact: Int32 = questsSystem.GetFact(n"mordeak_dollchip_hud_opacity");
    this.m_backgroundOpacity = opacityFact >= 1 && opacityFact <= 101 ? opacityFact - 1 : 100;
  }
}

public class MordeakDollChipRCFSystem extends ScriptableSystem {
  private func OnAttach() -> Void {
    GameInstance.GetCallbackSystem()
      .RegisterCallback(n"Session/Ready", this, n"OnSessionReady")
      .SetLifetime(CallbackLifetime.Forever);
  }

  protected cb func OnSessionReady(event: ref<GameSessionEvent>) -> Void {
    let provider: ref<MordeakDollChipSettingsProvider> = new MordeakDollChipSettingsProvider();
    provider.InitializeFromFacts(this.GetGameInstance());
    DVRCF.Register(
      this.GetGameInstance(),
      "MordeakTechnica",
      "Mordeak Technica",
      "DollChip HUD settings.",
      provider
    );
  }
}
