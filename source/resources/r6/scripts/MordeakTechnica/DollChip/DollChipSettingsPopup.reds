module MordeakTechnica

import Codeware.UI.*
import RedscriptConfigFramework.*

public class MordeakDollChipSettingsOpen extends DelayCallback {
  public let game: GameInstance;
  public let provider: ref<MordeakDollChipSettingsProvider>;
  public let attempts: Int32;

  // Wait for the picker to detach before its popup context is replaced.
  public func Call() -> Void {
    let hub: ref<DVRCF_Hub> = DVRCF_Hub.Get(this.game);
    if IsDefined(hub) && hub.IsOpen() {
      this.attempts += 1;
      if this.attempts < 40 {
        GameInstance.GetDelaySystem(this.game).DelayCallback(this, 0.05, false);
      } else {
        FTLog("[MordeakTechnica] Could not open HUD settings: RCF picker did not close.");
      }
      return;
    }
    if !MordeakDollChipSettingsPopup.Open(this.game, this.provider) {
      FTLog("[MordeakTechnica] Could not open the HUD settings preview.");
    }
  }
}

public class MordeakDollChipSettingsClick extends IScriptable {
  public let popup: wref<MordeakDollChipSettingsPopup>;
  public let row: Int32;
  public let delta: Int32;

  public cb func OnRelease(evt: ref<inkPointerEvent>) -> Bool {
    if evt.IsAction(n"click") && IsDefined(this.popup) {
      this.popup.Activate(this.row, this.delta);
      evt.Handle();
      return true;
    }
    return false;
  }
}

public class MordeakDollChipSettingsPopup extends DVRCF_HostedPopup {
  private let m_game: GameInstance;
  private let m_provider: ref<MordeakDollChipSettingsProvider>;
  private let m_settings: ref<DVRCFSettings>;
  private let m_preview: ref<MordeakHUDPreview>;
  private let m_labels: array<wref<inkText>>;
  private let m_values: array<wref<inkText>>;
  private let m_callbacks: array<ref<MordeakDollChipSettingsClick>>;
  private let m_selected: Int32;
  private let m_listening: Bool;
  private let m_closing: Bool;

  public static func Show(game: GameInstance, provider: ref<MordeakDollChipSettingsProvider>) -> Bool {
    let inkSystem: ref<inkSystem> = GameInstance.GetInkSystem();
    let layer: ref<inkLayerWrapper> = IsDefined(inkSystem) ? inkSystem.GetLayer(n"inkHUDLayer") : null;
    if !IsDefined(layer) || !IsDefined(layer.GetGameController()) || !IsDefined(DVRCF_Hub.Get(game)) {
      return false;
    }
    let callback: ref<MordeakDollChipSettingsOpen> = new MordeakDollChipSettingsOpen();
    callback.game = game;
    callback.provider = provider;
    GameInstance.GetDelaySystem(game).DelayCallback(callback, 0.05, false);
    return true;
  }

  public static func Open(game: GameInstance, provider: ref<MordeakDollChipSettingsProvider>) -> Bool {
    let popup: ref<MordeakDollChipSettingsPopup> = new MordeakDollChipSettingsPopup();
    popup.m_game = game;
    popup.m_provider = provider;
    return popup.OpenInGame();
  }

  public func GetQueueName() -> CName {
    return n"mordeak_dollchip_settings";
  }

  protected cb func OnCreate() -> Void {
    super.OnCreate();
    this.m_container.SetWidth(1600.0);
    this.m_container.SetHeight(1100.0);

    let header: ref<InGamePopupHeader> = InGamePopupHeader.Create();
    header.SetTitle("Mordeak Technica // DollChip HUD");
    header.Reparent(this);

    let footer: ref<InGamePopupFooter> = InGamePopupFooter.Create();
    footer.Reparent(this);

    let content: ref<InGamePopupContent> = InGamePopupContent.Create();
    content.Reparent(this);
    DVRCF_DrawFrame(content.GetRootCompoundWidget());
    let canvas: ref<inkCanvas> = new inkCanvas();
    canvas.SetSize(content.GetSize());
    canvas.Reparent(content.GetRootCompoundWidget());

    this.m_settings = new DVRCFSettings();
    this.m_settings.Load(this.m_game);

    this.BuildRow(canvas, 0, "HUD Color", 35.0);
    this.BuildRow(canvas, 1, "Background Color", 180.0);
    this.BuildRow(canvas, 2, "Background Opacity (%)", 325.0);
    this.MakeButton(canvas, "RESET", 35.0, 535.0, 150.0, 3, 0);
    this.MakeButton(canvas, "DONE", 210.0, 535.0, 150.0, 4, 0);
    MordeakCyberwareHUDSystem.CreateText(
      canvas, n"MordeakSettingsHelp", "Arrows / D-pad: select and adjust\nR / gamepad reset: reset settings\nEsc / back: done",
      35.0, 620.0, 590.0, 110.0, 22, HDRColor(0.7, 0.75, 0.82, 1.0)
    );

    MordeakCyberwareHUDSystem.CreateText(
      canvas, n"MordeakPreviewTitle", "HUD PREVIEW // SAMPLE DATA",
      730.0, 35.0, 610.0, 36.0, 23, HDRColor(0.7, 0.75, 0.82, 1.0)
    );
    let panel: ref<inkCanvas> = new inkCanvas();
    panel.SetName(n"MordeakSettingsPreview");
    panel.SetAnchor(inkEAnchor.TopLeft);
    panel.SetAnchorPoint(Vector2(0.0, 0.0));
    panel.SetSize(Vector2(760.0, 710.0));
    panel.SetTranslation(Vector2(730.0, 85.0));
    panel.SetScale(Vector2(0.8, 0.8));
    panel.SetInteractive(false);
    panel.Reparent(canvas);
    this.m_preview = new MordeakHUDPreview();
    MordeakCyberwareHUDSystem.BuildPanel(canvas, panel, this.m_game, null, this.m_preview);
    this.RefreshValues();
  }

  private func BuildRow(canvas: ref<inkCanvas>, row: Int32, title: String, y: Float) -> Void {
    let label: ref<inkText> = MordeakCyberwareHUDSystem.CreateText(
      canvas, StringToName("MordeakSettingsLabel" + IntToString(row)), title,
      35.0, y, 560.0, 38.0, 27, HDRColor(1.0, 1.0, 1.0, 1.0)
    );
    ArrayPush(this.m_labels, label);
    this.MakeButton(canvas, "-", 35.0, y + 48.0, 75.0, row, -1);
    let value: ref<inkText> = MordeakCyberwareHUDSystem.CreateText(
      canvas, StringToName("MordeakSettingsValue" + IntToString(row)), "",
      130.0, y + 48.0, 185.0, 48.0, 27, HDRColor(1.0, 1.0, 1.0, 1.0)
    );
    ArrayPush(this.m_values, value);
    this.MakeButton(canvas, "+", 335.0, y + 48.0, 75.0, row, 1);
    if row == 2 {
      this.MakeButton(canvas, "-10", 430.0, y + 48.0, 75.0, row, -10);
      this.MakeButton(canvas, "+10", 525.0, y + 48.0, 75.0, row, 10);
    }
  }

  private func MakeButton(canvas: ref<inkCanvas>, text: String, x: Float, y: Float, width: Float, row: Int32, delta: Int32) -> Void {
    let button: ref<inkRectangle> = MordeakCyberwareHUDSystem.CreateRectangle(
      canvas, n"MordeakSettingsButton", x, y, width, 48.0, HDRColor(0.28, 0.06, 0.10, 0.95)
    );
    button.SetInteractive(true);
    let callback: ref<MordeakDollChipSettingsClick> = new MordeakDollChipSettingsClick();
    callback.popup = this;
    callback.row = row;
    callback.delta = delta;
    ArrayPush(this.m_callbacks, callback);
    button.RegisterToCallback(n"OnRelease", callback, n"OnRelease");
    MordeakCyberwareHUDSystem.CreateText(
      canvas, n"MordeakSettingsButtonText", text, x + 12.0, y, width - 12.0, 48.0, 25, HDRColor(1.0, 0.82, 0.84, 1.0)
    );
  }

  private func ColorName(value: Int32) -> String {
    if value == 1 { return "Yellow"; }
    if value == 2 { return "Blue"; }
    if value == 3 { return "Pink"; }
    if value == 4 { return "Black"; }
    return "Red";
  }

  private func RefreshValues() -> Void {
    this.m_values[0].SetText(this.ColorName(this.m_provider.GetInt("hud_color")));
    this.m_values[1].SetText(this.ColorName(this.m_provider.GetInt("background_color")));
    this.m_values[2].SetText(IntToString(this.m_provider.GetInt("background_opacity")) + "%");
    let i: Int32 = 0;
    while i < ArraySize(this.m_labels) {
      this.m_labels[i].SetTintColor(i == this.m_selected ? HDRColor(1.0, 0.78, 0.08, 1.0) : HDRColor(1.0, 1.0, 1.0, 1.0));
      i += 1;
    }
    this.m_preview.Update(
      this.m_provider.GetInt("hud_color") + 1,
      this.m_provider.GetInt("background_color") + 2,
      this.m_provider.GetInt("background_opacity")
    );
  }

  public func Activate(row: Int32, delta: Int32) -> Void {
    if this.m_closing || !this.IsTopPopup() { return; }
    if row == 4 {
      this.Close();
      return;
    }
    if row == 3 {
      let schema: ref<DVRCF_Schema> = this.m_provider.BuildSchema();
      DVRCF_Store.ResetRows(this.m_game, "MordeakTechnica", this.m_provider, schema, schema.tabs[0].sections[0].rows);
      this.RefreshValues();
      return;
    }
    this.m_selected = row;
    let key: String = row == 0 ? "hud_color" : row == 1 ? "background_color" : "background_opacity";
    let value: Int32 = this.m_provider.GetInt(key) + delta;
    if row < 2 {
      if value < 0 { value = 4; }
      if value > 4 { value = 0; }
    }
    this.m_provider.SetInt(key, value);
    this.RefreshValues();
  }

  protected cb func OnShown() -> Void {
    super.OnShown();
    this.m_listening = true;
    GameInstance.GetCallbackSystem().RegisterCallback(n"Input/Key", this, n"OnSettingsKey", true);
  }

  protected cb func OnSettingsKey(event: ref<KeyInputEvent>) -> Void {
    if this.m_closing || !this.IsTopPopup() || !Equals(event.GetAction(), EInputAction.IACT_Press) { return; }
    let key: EInputKey = event.GetKey();
    let code: Int32 = EnumInt(key);
    if Equals(key, EInputKey.IK_Up) || Equals(key, EInputKey.IK_Pad_DigitUp) {
      this.m_selected = (this.m_selected + 2) % 3;
      this.RefreshValues();
    } else {
      if Equals(key, EInputKey.IK_Down) || Equals(key, EInputKey.IK_Pad_DigitDown) {
        this.m_selected = (this.m_selected + 1) % 3;
        this.RefreshValues();
      } else {
        if Equals(key, EInputKey.IK_Left) || Equals(key, EInputKey.IK_Pad_DigitLeft) {
          this.Activate(this.m_selected, -1);
        } else {
          if Equals(key, EInputKey.IK_Right) || Equals(key, EInputKey.IK_Pad_DigitRight) {
            this.Activate(this.m_selected, 1);
          } else {
            if Equals(key, EInputKey.IK_R) || code == this.m_settings.PadKey("padReset") {
              this.Activate(3, 0);
            } else {
              if code == this.m_settings.PadKey("padBack") {
                this.Close();
              }
            }
          }
        }
      }
    }
  }

  public func Close() -> Void {
    if this.m_closing { return; }
    this.m_closing = true;
    super.Close();
  }

  protected cb func OnDetach() -> Void {
    if this.m_listening {
      GameInstance.GetCallbackSystem().UnregisterCallback(n"Input/Key", this, n"OnSettingsKey");
      this.m_listening = false;
    }
    DVRCF_Store.PersistFrom(this.m_game, "MordeakTechnica", this.m_provider, this.m_provider.BuildSchema());
    this.m_provider.OnSave();
    super.OnDetach();
  }
}
