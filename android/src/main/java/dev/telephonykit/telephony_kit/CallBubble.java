package dev.telephonykit.telephony_kit;

import android.app.Activity;
import android.app.ActivityManager;
import android.app.Application;
import android.content.Context;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.Settings;
import android.telecom.Call;
import android.telecom.CallAudioState;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.WindowManager;
import android.widget.Chronometer;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * A small floating button shown over other apps while a call is live and the
 * app is in the background. Tapping it opens a panel with mute, speaker and
 * hang up (answer and decline while ringing) and a button back to the call
 * screen. It can be dragged and snaps to the nearest screen edge.
 *
 * <p>Needs the "display over other apps" permission ({@code
 * SYSTEM_ALERT_WINDOW}, declared by the app and granted by the user in
 * Settings). Without it the bubble is simply not shown.
 *
 * <p>The setting is saved, so the bubble also works when Flutter is not
 * running. The process stays alive during a call because the system is bound
 * to the in-call service.
 */
public final class CallBubble {
  private CallBubble() {}

  private static final String PREFS = "telephony_kit_bubble";
  private static final Handler main = new Handler(Looper.getMainLooper());

  private static int startedActivities = 0;
  private static boolean appVisible = true;
  private static boolean tracking = false;

  private static WindowManager windowManager;
  private static LinearLayout root;
  private static WindowManager.LayoutParams params;
  private static boolean expanded = false;
  private static String shownCallId;

  // Button labels, replaceable with setLabels for other languages.
  private static String labelAnswer = "Answer";
  private static String labelDecline = "Decline";
  private static String labelMute = "Mute";
  private static String labelUnmute = "Unmute";
  private static String labelSpeaker = "Speaker";
  private static String labelEnd = "End";
  private static String labelOpen = "Open";

  private static SharedPreferences prefs(Context context) {
    return context.getApplicationContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE);
  }

  // ---------------------------------------------------------------------------
  // Settings (called from Dart)
  // ---------------------------------------------------------------------------

  /** Whether the bubble is shown when the app leaves the screen during a call. */
  public static boolean isEnabled(Context context) {
    return prefs(context).getBoolean("enabled", false);
  }

  /** Turns the bubble on or off. Saved, so it also applies after a restart. */
  public static void setEnabled(Context context, boolean enabled) {
    prefs(context).edit().putBoolean("enabled", enabled).apply();
    Context app = context.getApplicationContext();
    trackAppVisibility(app);
    runOnMain(() -> update(app));
  }

  /** Whether the bubble is on screen now. */
  public static boolean isShowing() {
    return root != null;
  }

  /** Replaces the button labels, for example with translations. */
  public static void setLabels(
      String answer,
      String decline,
      String mute,
      String unmute,
      String speaker,
      String end,
      String open) {
    labelAnswer = answer;
    labelDecline = decline;
    labelMute = mute;
    labelUnmute = unmute;
    labelSpeaker = speaker;
    labelEnd = end;
    labelOpen = open;
    runOnMain(CallBubble::refresh);
  }

  /** Whether the app has an activity on screen, as tracked by the bubble. */
  public static boolean isAppVisible() {
    return appVisible;
  }

  // ---------------------------------------------------------------------------
  // App visibility
  // ---------------------------------------------------------------------------

  /**
   * Starts following the app's activities so the bubble can appear when the
   * last one leaves the screen. Safe to call many times.
   */
  static synchronized void trackAppVisibility(Context context) {
    if (tracking) return;
    Context app = context.getApplicationContext();
    if (!(app instanceof Application)) return;
    tracking = true;
    appVisible = isForeground(app);
    ((Application) app)
        .registerActivityLifecycleCallbacks(
            new Application.ActivityLifecycleCallbacks() {
              @Override
              public void onActivityStarted(Activity activity) {
                startedActivities++;
                setAppVisible(app, true);
              }

              @Override
              public void onActivityStopped(Activity activity) {
                // Tracking may start while an activity is already showing, so
                // the count can be one short; never let it go negative.
                startedActivities = Math.max(0, startedActivities - 1);
                // A configuration change stops and restarts the activity.
                if (startedActivities == 0 && !activity.isChangingConfigurations()) {
                  setAppVisible(app, false);
                }
              }

              @Override
              public void onActivityCreated(Activity activity, Bundle state) {}

              @Override
              public void onActivityResumed(Activity activity) {}

              @Override
              public void onActivityPaused(Activity activity) {}

              @Override
              public void onActivitySaveInstanceState(Activity activity, Bundle state) {}

              @Override
              public void onActivityDestroyed(Activity activity) {}
            });
  }

  private static boolean isForeground(Context context) {
    ActivityManager.RunningAppProcessInfo info = new ActivityManager.RunningAppProcessInfo();
    ActivityManager.getMyMemoryState(info);
    return info.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND;
  }

  private static void setAppVisible(Context context, boolean visible) {
    if (appVisible == visible) return;
    appVisible = visible;
    update(context);
  }

  // ---------------------------------------------------------------------------
  // Showing and hiding
  // ---------------------------------------------------------------------------

  /** Shows, refreshes or hides the bubble to match the calls. Main thread. */
  static void update(Context context) {
    if (Looper.myLooper() != Looper.getMainLooper()) {
      main.post(() -> update(context));
      return;
    }
    String callId = currentCallId();
    boolean want =
        callId != null
            && !appVisible
            && isEnabled(context)
            && Settings.canDrawOverlays(context);
    if (!want) {
      hide();
      return;
    }
    shownCallId = callId;
    if (root == null) create(context.getApplicationContext());
    refresh();
  }

  /** Removes the bubble if it is showing. */
  public static void hide() {
    if (Looper.myLooper() != Looper.getMainLooper()) {
      main.post(CallBubble::hide);
      return;
    }
    if (root != null && windowManager != null) {
      try {
        windowManager.removeView(root);
      } catch (RuntimeException ignored) {
        // Already removed.
      }
    }
    root = null;
    expanded = false;
    shownCallId = null;
  }

  /** The ringing call, else the active one, else any live top level call. */
  private static String currentCallId() {
    String ringing = null, active = null, other = null;
    for (String id : CallManager.getCallIds()) {
      if (!CallManager.getParentId(id).isEmpty()) continue;
      int state = CallManager.getState(id);
      if (state == Call.STATE_RINGING) ringing = id;
      else if (state == Call.STATE_ACTIVE) active = id;
      else if (state != Call.STATE_DISCONNECTED
          && state != Call.STATE_DISCONNECTING
          && state != -1) other = id;
    }
    if (ringing != null) return ringing;
    if (active != null) return active;
    return other;
  }

  private static int dp(Context context, float value) {
    return Math.round(
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, value, context.getResources().getDisplayMetrics()));
  }

  private static GradientDrawable round(int color, float radius) {
    GradientDrawable d = new GradientDrawable();
    d.setColor(color);
    d.setCornerRadius(radius);
    return d;
  }

  @SuppressWarnings("deprecation")
  private static void create(Context context) {
    windowManager = context.getSystemService(WindowManager.class);
    if (windowManager == null) return;

    int type =
        Build.VERSION.SDK_INT >= 26
            ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            : WindowManager.LayoutParams.TYPE_PHONE;
    params =
        new WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
            PixelFormat.TRANSLUCENT);
    params.gravity = Gravity.TOP | Gravity.START;
    SharedPreferences p = prefs(context);
    params.x = p.getInt("x", 0);
    params.y = p.getInt("y", dp(context, 160));

    root = new LinearLayout(context);
    root.setOrientation(LinearLayout.VERTICAL);
    try {
      windowManager.addView(root, params);
    } catch (RuntimeException e) {
      // Permission revoked between the check and now.
      root = null;
    }
  }

  /** Rebuilds the bubble's content for the current call. */
  private static void refresh() {
    LinearLayout layout = root;
    String callId = shownCallId;
    if (layout == null || callId == null) return;
    Context context = layout.getContext();
    layout.removeAllViews();

    ImageView bubble = new ImageView(context);
    int size = dp(context, 56);
    int state = CallManager.getState(callId);
    boolean ringing = state == Call.STATE_RINGING;
    bubble.setBackground(round(ringing ? 0xFF2E7D32 : 0xFF00796B, size / 2f));
    bubble.setImageResource(android.R.drawable.sym_action_call);
    bubble.setColorFilter(Color.WHITE);
    int pad = dp(context, 14);
    bubble.setPadding(pad, pad, pad, pad);
    bubble.setElevation(dp(context, 6));
    bubble.setContentDescription(labelOpen);
    LinearLayout.LayoutParams bubbleParams = new LinearLayout.LayoutParams(size, size);
    bubbleParams.setMargins(dp(context, 4), dp(context, 4), dp(context, 4), dp(context, 4));
    bubble.setOnTouchListener(new DragListener(context));

    View panel = expanded ? panel(context, callId, ringing) : null;
    boolean panelAbove =
        params != null && params.y > context.getResources().getDisplayMetrics().heightPixels / 2;
    if (panel != null && panelAbove) layout.addView(panel);
    layout.addView(bubble, bubbleParams);
    if (panel != null && !panelAbove) layout.addView(panel);
    if (windowManager != null && params != null) {
      try {
        windowManager.updateViewLayout(layout, params);
      } catch (RuntimeException ignored) {
        // Removed meanwhile.
      }
    }
  }

  private static View panel(Context context, String callId, boolean ringing) {
    LinearLayout panel = new LinearLayout(context);
    panel.setOrientation(LinearLayout.VERTICAL);
    panel.setBackground(round(0xF0202124, dp(context, 16)));
    int pad = dp(context, 12);
    panel.setPadding(pad, pad, pad, pad);
    panel.setElevation(dp(context, 8));

    TextView name = new TextView(context);
    String label = CallManager.getDisplayName(callId);
    if (label.isEmpty()) label = CallManager.getNumber(callId);
    name.setText(label);
    name.setTextColor(Color.WHITE);
    name.setTextSize(TypedValue.COMPLEX_UNIT_SP, 16);
    panel.addView(name);

    long connectedAt = CallManager.getConnectTimeMillis(callId);
    if (!ringing && connectedAt > 0) {
      Chronometer timer = new Chronometer(context);
      timer.setBase(SystemClock.elapsedRealtime() - (System.currentTimeMillis() - connectedAt));
      timer.setTextColor(0xFFB0BEC5);
      timer.start();
      panel.addView(timer);
    }

    LinearLayout row = new LinearLayout(context);
    row.setOrientation(LinearLayout.HORIZONTAL);
    row.setPadding(0, dp(context, 8), 0, 0);
    if (ringing) {
      row.addView(button(context, labelAnswer, 0xFF2E7D32, () -> CallManager.answer(callId)));
      row.addView(button(context, labelDecline, 0xFFC62828, () -> CallManager.reject(callId)));
    } else {
      boolean muted = CallManager.isMuted();
      boolean speaker = CallManager.getAudioRoute() == CallAudioState.ROUTE_SPEAKER;
      row.addView(
          button(
              context,
              muted ? labelUnmute : labelMute,
              muted ? 0xFF546E7A : 0xFF37474F,
              () -> CallManager.setMuted(!muted)));
      row.addView(
          button(
              context,
              labelSpeaker,
              speaker ? 0xFF00796B : 0xFF37474F,
              () -> CallManager.setSpeakerOn(!speaker)));
      row.addView(button(context, labelEnd, 0xFFC62828, () -> CallManager.disconnect(callId)));
    }
    row.addView(
        button(context, labelOpen, 0xFF1565C0, () -> CallManager.requestCallScreen(context, callId)));
    panel.addView(row);
    return panel;
  }

  private static View button(Context context, String text, int color, Runnable action) {
    TextView b = new TextView(context);
    b.setText(text);
    b.setTextColor(Color.WHITE);
    b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
    b.setGravity(Gravity.CENTER);
    b.setBackground(round(color, dp(context, 18)));
    int h = dp(context, 12), v = dp(context, 8);
    b.setPadding(h, v, h, v);
    b.setMinWidth(dp(context, 56));
    LinearLayout.LayoutParams lp =
        new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
    lp.setMarginEnd(dp(context, 6));
    b.setLayoutParams(lp);
    b.setClickable(true);
    b.setOnClickListener(
        v1 -> {
          action.run();
          // Telecom reports the change a moment later; refresh after it.
          main.postDelayed(CallBubble::refresh, 300);
        });
    return b;
  }

  /** Drags the bubble; a tap without movement opens or closes the panel. */
  private static final class DragListener implements View.OnTouchListener {
    private final Context context;
    private final int slop;
    private float downX, downY;
    private int startX, startY;
    private boolean dragging;

    DragListener(Context context) {
      this.context = context;
      this.slop = ViewConfiguration.get(context).getScaledTouchSlop();
    }

    @Override
    public boolean onTouch(View view, MotionEvent event) {
      WindowManager.LayoutParams p = params;
      if (p == null || root == null || windowManager == null) return false;
      switch (event.getActionMasked()) {
        case MotionEvent.ACTION_DOWN:
          downX = event.getRawX();
          downY = event.getRawY();
          startX = p.x;
          startY = p.y;
          dragging = false;
          return true;
        case MotionEvent.ACTION_MOVE:
          float dx = event.getRawX() - downX, dy = event.getRawY() - downY;
          if (!dragging && Math.hypot(dx, dy) > slop) dragging = true;
          if (dragging) {
            p.x = startX + Math.round(dx);
            p.y = Math.max(0, startY + Math.round(dy));
            try {
              windowManager.updateViewLayout(root, p);
            } catch (RuntimeException ignored) {
              // Removed meanwhile.
            }
          }
          return true;
        case MotionEvent.ACTION_UP:
          if (dragging) {
            int width = context.getResources().getDisplayMetrics().widthPixels;
            int center = p.x + root.getWidth() / 2;
            p.x = center < width / 2 ? 0 : Math.max(0, width - root.getWidth());
            prefs(context).edit().putInt("x", p.x).putInt("y", p.y).apply();
            refresh();
          } else {
            view.performClick();
            expanded = !expanded;
            refresh();
          }
          return true;
        default:
          return false;
      }
    }
  }

  private static void runOnMain(Runnable r) {
    if (Looper.myLooper() == Looper.getMainLooper()) r.run();
    else main.post(r);
  }
}
