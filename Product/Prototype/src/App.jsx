import { useEffect, useMemo, useRef, useState } from "react";
import { flushSync } from "react-dom";
import {
  Activity,
  Anchor as AnchorIcon,
  ArrowLeft,
  Bell,
  Check,
  CheckCircle2,
  ChevronDown,
  ChevronRight,
  ChevronUp,
  CircleAlert,
  Cloud,
  FileCheck2,
  Gauge,
  Grip,
  History,
  LayoutGrid,
  Layers3,
  ListChecks,
  MapPin,
  Mic,
  Pause,
  Pencil,
  Play,
  Plus,
  Radio,
  RectangleHorizontal,
  RotateCcw,
  Sailboat,
  Settings2,
  ShieldCheck,
  Smartphone,
  Sparkles,
  TimerReset,
  Trash2,
  UserRound,
  Waves,
  Wifi,
  X,
  Zap,
} from "lucide-react";
import logoUrl from "../LOGO.png";
import { initialGoal, initialTasks, notifications, returnChanges } from "./data";

const statusIcons = {
  running: Activity,
  attention: CircleAlert,
  queued: TimerReset,
  done: CheckCircle2,
};

const widgetDimensions = {
  "2x2": { columns: 2, rows: 2, label: "2×2" },
  "4x2": { columns: 4, rows: 2, label: "4×2" },
  "2x4": { columns: 2, rows: 4, label: "2×4" },
  "4x4": { columns: 4, rows: 4, label: "4×4" },
};

const widgetSizeOptions = Object.keys(widgetDimensions);

const directionOptions = [
  { id: "A", title: "纪实留白", note: "人物与工作流" },
  { id: "B", title: "产品聚焦", note: "Anchor 为视觉中心" },
  { id: "C", title: "动势叙事", note: "更强节奏与转场" },
];

function getGreeting() {
  const hour = new Date().getHours();
  if (hour < 11) return "早上好";
  if (hour < 18) return "下午好";
  return "晚上好";
}

function App() {
  const initialSetup = new URLSearchParams(window.location.search).get("setup") === "1";
  const [showSplash, setShowSplash] = useState(!initialSetup);
  const [page, setPage] = useState(initialSetup ? "setup" : "home");
  const [presence, setPresence] = useState("desk");
  const [orientation, setOrientation] = useState("portrait");
  const [sheet, setSheet] = useState(null);
  const [anchorOrigin, setAnchorOrigin] = useState("home");
  const [taskOrigin, setTaskOrigin] = useState("home");
  const [anchorRecords, setAnchorRecords] = useState([]);
  const [selectedTaskId, setSelectedTaskId] = useState(null);
  const [tasks, setTasks] = useState(initialTasks);
  const [visibleTaskCount, setVisibleTaskCount] = useState(Math.min(4, initialTasks.length));
  const [taskWidgetSizes, setTaskWidgetSizes] = useState(() =>
    Object.fromEntries(initialTasks.map((task) => [task.id, "2x2"])),
  );
  const [goal, setGoal] = useState(initialGoal);
  const [notificationItems, setNotificationItems] = useState(notifications);
  const [successfulReturns, setSuccessfulReturns] = useState(2);
  const [sessionComplete, setSessionComplete] = useState(false);
  const [awayStarted, setAwayStarted] = useState(null);
  const [handoffPhase, setHandoffPhase] = useState("idle");
  const handoffTimers = useRef([]);
  const [toast, setToast] = useState("");
  const [settings, setSettings] = useState({
    liveActivity: true,
    quietMode: true,
    haptics: true,
  });

  useEffect(() => {
    if (!showSplash) return undefined;
    const timer = window.setTimeout(() => setShowSplash(false), 1150);
    return () => window.clearTimeout(timer);
  }, [showSplash]);

  useEffect(() => () => {
    handoffTimers.current.forEach((timer) => window.clearTimeout(timer));
  }, []);

  useEffect(() => {
    if (!toast) return undefined;
    const timer = window.setTimeout(() => setToast(""), 2600);
    return () => window.clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    setVisibleTaskCount((current) => {
      const minimum = Math.min(2, tasks.length);
      return Math.max(minimum, Math.min(current, tasks.length));
    });
  }, [tasks.length]);

  useEffect(() => {
    if (presence !== "away") return undefined;
    const timer = window.setInterval(() => {
      setTasks((current) =>
        current.map((task) => {
          if (task.status !== "running" || task.progress >= 96) return task;
          const progress = Math.min(task.progress + 1, 96);
          return { ...task, progress, updated: "刚刚" };
        }),
      );
    }, 2800);
    return () => window.clearInterval(timer);
  }, [presence]);

  const selectedTask = useMemo(
    () => tasks.find((task) => task.id === selectedTaskId),
    [selectedTaskId, tasks],
  );
  const visibleTasks = useMemo(
    () => tasks.slice(0, Math.min(visibleTaskCount, tasks.length)),
    [tasks, visibleTaskCount],
  );

  const updateTaskWidgetSize = (taskId, size) => {
    if (!widgetDimensions[size]) return;
    setTaskWidgetSizes((current) => ({ ...current, [taskId]: size }));
  };

  const openTask = (taskId, origin = "home") => {
    setNotificationItems((current) =>
      current.map((item) => (item.taskId === taskId ? { ...item, unread: false } : item)),
    );
    setTaskOrigin(origin);
    setSelectedTaskId(taskId);
    setSheet("task");
  };

  const closeTaskSheet = () => {
    setSheet(taskOrigin === "return" ? "return" : null);
  };

  const openNotification = (item) => {
    setNotificationItems((current) =>
      current.map((notification) =>
        notification.id === item.id ? { ...notification, unread: false } : notification,
      ),
    );
    if (item.taskId) {
      openTask(item.taskId);
      return;
    }
    setSheet(null);
    setPage("profile");
    setToast("已定位到保存的上下文");
  };

  const simulatePresence = (nextPresence) => {
    if (nextPresence === "away") {
      if (presence === "away" || handoffPhase !== "idle") return;
      handoffTimers.current.forEach((timer) => window.clearTimeout(timer));
      handoffTimers.current = [];
      setHandoffPhase("gathering");
      setPage("home");
      setSheet(null);
      setToast("");
      handoffTimers.current.push(
        window.setTimeout(() => setHandoffPhase("secured"), 760),
        window.setTimeout(() => {
          setPresence("away");
          setAwayStarted(Date.now() - 18 * 60 * 1000);
        }, 980),
        window.setTimeout(() => setHandoffPhase("idle"), 1850),
      );
      return;
    }

    if (presence !== "away" || handoffPhase !== "idle") return;
    setPresence("desk");
    setPage("home");
    setSheet("return");
    setToast("");
  };

  const openAnchorCapture = (origin) => {
    setAnchorOrigin(origin);
    setSheet("anchor");
  };

  const closeAnchorCapture = () => {
    setSheet(anchorOrigin === "return" ? "return" : null);
  };

  const saveAnchorRecord = (note) => {
    const nextRecord = {
      id: Date.now(),
      note: note.trim(),
      origin: anchorOrigin,
      createdAt: "刚刚",
    };
    setAnchorRecords((current) => [nextRecord, ...current]);
    setSheet(anchorOrigin === "return" ? "return" : null);
    setToast("锚点已记录，工作状态保持不变");
  };

  const completeReturn = () => {
    setPresence("desk");
    setAwayStarted(null);
    setSuccessfulReturns((current) => current + 1);
    setTaskOrigin("home");
    setSheet(null);
    setPage("home");
    setToast("已返航，上下文保持就绪");
  };

  const performTaskAction = (task, direction = "B", { inline = false } = {}) => {
    const returnDirectlyToWork = !inline && taskOrigin === "return";

    const finishTaskAction = (message) => {
      if (returnDirectlyToWork) {
        setPresence("desk");
        setAwayStarted(null);
        setSuccessfulReturns((current) => current + 1);
        setTaskOrigin("home");
        setSheet(null);
        setPage("home");
        setToast(`${message}，工作流已继续`);
        return;
      }
      if (inline) {
        setToast(message);
        return;
      }
      closeTaskSheet();
      setToast(message);
    };

    if (task.status === "attention") {
      setTasks((current) =>
        current.map((item) =>
          item.id === task.id
            ? {
                ...item,
                status: "running",
                statusLabel: "已确认",
                progress: Math.max(item.progress, 85),
                detail: `已采用方向 ${direction}，正在生成镜头描述`,
                eta: "约 5 分钟",
                updated: "刚刚",
                activity: [...item.activity, `你确认了方向 ${direction}`],
              }
            : item,
        ),
      );
      finishTaskAction(`已确认方向 ${direction}`);
      return;
    }
    if (task.status === "queued") {
      setTasks((current) =>
        current.map((item) =>
          item.id === task.id
            ? {
                ...item,
                status: "running",
                statusLabel: "已提前",
                detail: "正在整理已确认素材并建立粗剪",
                eta: "约 24 分钟",
                updated: "刚刚",
                activity: [...item.activity, "你将任务提前到运行队列"],
              }
            : item,
        ),
      );
      finishTaskAction("已调整优先级");
      return;
    }
    setToast(task.status === "done" ? "产出已在 Mac 上打开" : "已在 Mac 上定位到当前任务");
    if (!inline) closeTaskSheet();
  };

  const handleSetupComplete = ({ nextGoal, nextTaskNames }) => {
    setGoal(nextGoal);
    setTasks((current) =>
      nextTaskNames.map((name, index) => {
        const template = current[index] || {
          ...initialTasks[index % initialTasks.length],
          id: `custom-${Date.now()}-${index}`,
          app: "手动任务",
          appCode: "A",
          appTone: "blue",
          detail: "等待 Anchor 获取最新状态",
          eta: "等待同步",
          activity: ["任务已添加到本次锚点"],
        };
        return {
          ...template,
          title: name,
          progress: index === 0 ? 8 : 0,
          status: index === 0 ? "running" : "queued",
          statusLabel: index === 0 ? "已启动" : "等待中",
          updated: "刚刚",
        };
      }),
    );
    setVisibleTaskCount(Math.min(4, nextTaskNames.length));
    setPage("home");
    setPresence("desk");
    setSessionComplete(false);
    setToast("新的锚点已建立");
  };

  const finishSession = () => {
    setSheet(null);
    setPage("insights");
    setSessionComplete(true);
    setToast("本次工作已收好，随时可以恢复");
  };

  const changeOrientation = (nextOrientation) => {
    if (nextOrientation === orientation) return;
    if (!document.startViewTransition) {
      setOrientation(nextOrientation);
      return;
    }
    const root = document.documentElement;
    if (root.classList.contains("orientation-view-transition")) return;
    root.classList.add("orientation-view-transition");
    const transition = document.startViewTransition(() => {
      flushSync(() => setOrientation(nextOrientation));
    });
    transition.finished.finally(() => root.classList.remove("orientation-view-transition"));
  };

  const unreadCount = notificationItems.filter((item) => item.unread).length;

  return (
    <div className="prototype-stage">
      <div
        className={`device-shell is-${orientation} ${handoffPhase !== "idle" ? "is-handoff" : ""}`}
        data-orientation={orientation}
        data-handoff={handoffPhase}
      >
        <div className="ios-app">
          {showSplash && <Splash />}
          {!showSplash && page === "setup" ? (
            <SetupScreen
              goal={goal}
              tasks={tasks}
              onCancel={() => setPage("home")}
              onComplete={handleSetupComplete}
              showCancel
            />
          ) : null}
          {!showSplash && page !== "setup" ? (
            <>
              <StatusBar />
              {page === "profile" ? (
                <ProfilePage
                  settings={settings}
                  anchorCount={anchorRecords.length}
                  sessionComplete={sessionComplete}
                  tasks={visibleTasks}
                  anchorRecords={anchorRecords}
                  successfulReturns={successfulReturns}
                  onChangeSetting={(key) =>
                    setSettings((current) => ({ ...current, [key]: !current[key] }))
                  }
                  onBack={() => setPage("home")}
                  onAccount={() => setSheet("account")}
                  onOpenDetail={(detail) => setSheet(detail)}
                />
              ) : (
                <div
                  className="screen-frame"
                >
                  <TopBar
                    presence={presence}
                    unreadCount={unreadCount}
                    onProfile={() => setPage("profile")}
                    onNotifications={() => setSheet("notifications")}
                  />
                  {presence === "away" ? (
                    <AwayDashboard
                      goal={goal}
                      tasks={visibleTasks}
                      widgetSizes={taskWidgetSizes}
                      awayStarted={awayStarted}
                      onOpenTask={openTask}
                      onResizeWidget={updateTaskWidgetSize}
                      onOpenLayout={() => setSheet("widget-layout")}
                    />
                  ) : page === "insights" ? (
                    <InsightsPage
                      tasks={visibleTasks}
                      anchorRecords={anchorRecords}
                      successfulReturns={successfulReturns}
                      completed={sessionComplete}
                      onBack={() => setPage("home")}
                      onNewAnchor={() => setPage("setup")}
                      onMemoryAction={(message) => setToast(message)}
                    />
                  ) : (
                    <FocusDashboard
                      orientation={orientation}
                      goal={goal}
                      tasks={visibleTasks}
                      widgetSizes={taskWidgetSizes}
                      anchorCount={anchorRecords.length}
                      onEditGoal={() => setSheet("goal")}
                      onOpenTask={openTask}
                      onTaskAction={(taskId, direction) => {
                        const task = tasks.find((item) => item.id === taskId);
                        if (task) performTaskAction(task, direction, { inline: true });
                      }}
                      onAnchor={() => openAnchorCapture("home")}
                      onResizeWidget={updateTaskWidgetSize}
                      onOpenLayout={() => setSheet("widget-layout")}
                    />
                  )}
                </div>
              )}
              <HomeIndicator />
            </>
          ) : null}

          {sheet === "task" && selectedTask && (
            <TaskSheet
              task={selectedTask}
              overReturn={taskOrigin === "return"}
              onClose={closeTaskSheet}
              onAction={(direction) => performTaskAction(selectedTask, direction)}
            />
          )}

          {sheet === "goal" && (
            <GoalSheet
              goal={goal}
              onClose={() => setSheet(null)}
              onSave={(nextGoal) => {
                setGoal(nextGoal);
                setSheet(null);
                setToast("本次锚点已更新");
              }}
            />
          )}

          {sheet === "notifications" && (
            <NotificationsSheet
              items={notificationItems}
              onClose={() => setSheet(null)}
              onOpen={openNotification}
            />
          )}

          {["profile-focus", "profile-contexts", "profile-anchors", "profile-session", "profile-return", "profile-decision", "profile-snapshot"].includes(sheet) && (
            <ProfileDetailSheet
              type={sheet}
              goal={goal}
              tasks={visibleTasks}
              anchorRecords={anchorRecords}
              successfulReturns={successfulReturns}
              sessionComplete={sessionComplete}
              onClose={() => setSheet(null)}
              onManage={() => setSheet("manage")}
              onFinish={() => setSheet("finish")}
            />
          )}

          {sheet === "manage" && (
            <ManageTasksSheet
              tasks={tasks}
              onClose={() => setSheet("profile-session")}
              onSave={(nextTasks) => {
                setTasks(nextTasks);
                setSheet("profile-session");
                setToast("进程顺序已更新");
              }}
            />
          )}

          {sheet === "widget-layout" && (
            <WidgetLayoutSheet
              tasks={tasks}
              visibleTaskCount={visibleTaskCount}
              widgetSizes={taskWidgetSizes}
              onVisibleTaskCount={setVisibleTaskCount}
              onSizeChange={updateTaskWidgetSize}
              onClose={() => setSheet(null)}
            />
          )}

          {["account", "icloud", "privacy", "sources"].includes(sheet) && (
            <InfoSheet type={sheet} onClose={() => setSheet(null)} />
          )}

          {sheet === "finish" && (
            <FinishSheet
              tasks={visibleTasks}
              onClose={() => setSheet("profile-session")}
              onFinish={finishSession}
            />
          )}

          {(sheet === "return" ||
            (sheet === "task" && taskOrigin === "return") ||
            (sheet === "anchor" && anchorOrigin === "return")) && (
            <ReturnSheet
              goal={goal}
              tasks={visibleTasks}
              awayStarted={awayStarted}
              onClose={() => {
                setSheet(null);
                setAwayStarted(null);
              }}
              onComplete={completeReturn}
              onOpenTask={(taskId) => openTask(taskId, "return")}
            />
          )}

          {sheet === "anchor" && (
            <AnchorCaptureSheet
              goal={goal}
              tasks={visibleTasks}
              origin={anchorOrigin}
              recentRecord={anchorRecords[0]}
              onClose={closeAnchorCapture}
              onSave={saveAnchorRecord}
            />
          )}

          {toast && <Toast message={toast} />}
          {handoffPhase !== "idle" && (
            <HandoffOverlay phase={handoffPhase} tasks={visibleTasks} />
          )}
        </div>
      </div>
      <PrototypeControls
        orientation={orientation}
        presence={presence}
        handoffPhase={handoffPhase}
        returning={sheet === "return" ||
          (sheet === "task" && taskOrigin === "return") ||
          (sheet === "anchor" && anchorOrigin === "return")}
        onOrientation={changeOrientation}
        onPresence={simulatePresence}
      />
    </div>
  );
}

function PrototypeControls({ orientation, presence, handoffPhase, returning, onOrientation, onPresence }) {
  const isHandingOff = handoffPhase !== "idle";
  const detectedState = isHandingOff
    ? handoffPhase === "secured" ? "Anchor 已接管" : "正在接管工作"
    : returning ? "已识别返回" : presence === "away" ? "已识别离开" : "在工位工作";

  return (
    <aside className={`prototype-controls ${isHandingOff ? "is-handoff" : ""}`} aria-label="原型模拟控制器">
      <div className="prototype-controls-heading">
        <span className="prototype-controls-icon"><Radio size={17} /></span>
        <span><strong>原型控制器</strong><small>设备外 · 不属于 App</small></span>
      </div>

      <div className="prototype-control-group">
        <span className="prototype-control-label">屏幕方向</span>
        <div className="prototype-segmented" role="group" aria-label="切换屏幕方向">
          <button
            className={orientation === "portrait" ? "active" : ""}
            onClick={() => onOrientation("portrait")}
            aria-pressed={orientation === "portrait"}
            data-testid="orientation-portrait"
          >
            <Smartphone size={15} /> 竖屏
          </button>
          <button
            className={orientation === "landscape" ? "active" : ""}
            onClick={() => onOrientation("landscape")}
            aria-pressed={orientation === "landscape"}
            data-testid="orientation-landscape"
          >
            <RectangleHorizontal size={16} /> 横屏
          </button>
        </div>
      </div>

      <div className="prototype-control-group">
        <span className="prototype-control-label">自动状态识别</span>
        <div className="prototype-segmented" role="group" aria-label="模拟自动状态识别">
          <button
            className={presence === "desk" ? "active" : ""}
            onClick={() => onPresence("desk")}
            aria-pressed={presence === "desk"}
            disabled={isHandingOff}
            data-testid="presence-desk"
          >
            在工位
          </button>
          <button
            className={presence === "away" || isHandingOff ? "active" : ""}
            onClick={() => onPresence("away")}
            aria-pressed={presence === "away" || isHandingOff}
            disabled={isHandingOff}
            data-testid="presence-away"
          >
            离开中
          </button>
        </div>
      </div>

      <div className={`prototype-detection ${presence === "away" ? "away" : ""} ${isHandingOff ? "is-handoff" : ""}`}>
        <i />
        <span><small>当前模拟</small><strong>{detectedState}</strong></span>
      </div>
    </aside>
  );
}

function Splash() {
  return (
    <div className="splash-screen" aria-label="Anchor 启动画面">
      <div className="logo-crop">
        <img src={logoUrl} alt="Anchor" />
      </div>
      <div className="splash-wordmark">ANCHOR</div>
    </div>
  );
}

function StatusBar() {
  const [time, setTime] = useState(() =>
    new Intl.DateTimeFormat("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false }).format(new Date()),
  );

  useEffect(() => {
    const timer = window.setInterval(() => {
      setTime(
        new Intl.DateTimeFormat("zh-CN", {
          hour: "2-digit",
          minute: "2-digit",
          hour12: false,
        }).format(new Date()),
      );
    }, 30000);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <div className="status-bar" aria-hidden="true">
      <span className="status-time">{time}</span>
      <span className="dynamic-island" />
      <span className="status-icons">
        <span className="signal-bars"><i /><i /><i /><i /></span>
        <Wifi size={13} strokeWidth={2.4} />
        <span className="battery"><i /></span>
      </span>
    </div>
  );
}

function ClayAvatar() {
  return (
    <span className="clay-avatar" aria-hidden="true">
      <i className="clay-avatar-shirt" />
      <i className="clay-avatar-face" />
      <i className="clay-avatar-hair" />
    </span>
  );
}

function HarborDoodles() {
  return (
    <div className="harbor-doodles" aria-hidden="true">
      <Waves className="harbor-doodle-waves" size={84} strokeWidth={1.7} />
      <Sailboat className="harbor-doodle-boat" size={39} strokeWidth={1.7} />
      <Sparkles className="harbor-doodle-sparkle" size={27} strokeWidth={1.7} />
      <i className="harbor-doodle-bubble bubble-one" />
      <i className="harbor-doodle-bubble bubble-two" />
      <i className="harbor-doodle-route" />
    </div>
  );
}

function TopBar({ presence, unreadCount, onProfile, onNotifications }) {
  return (
    <header className="top-bar">
      <button className="avatar-button" onClick={onProfile} aria-label="打开我的页面" title="我的">
        <ClayAvatar />
      </button>
      <div className="brand-lockup">
        <span className="brand-name">Anchor</span>
        <span className={`sync-state ${presence === "away" ? "away" : ""}`}>
          <i />
          {presence === "away" ? "远程同步中" : "已连接 Mac"}
        </span>
      </div>
      <div className="top-actions">
        <button className="icon-button" onClick={onNotifications} aria-label="打开通知" title="通知">
          <Bell size={19} />
          {unreadCount > 0 && <span className="notification-dot" />}
        </button>
      </div>
    </header>
  );
}

function FocusDashboard({
  orientation,
  goal,
  tasks,
  widgetSizes,
  anchorCount,
  onEditGoal,
  onOpenTask,
  onTaskAction,
  onAnchor,
  onResizeWidget,
  onOpenLayout,
}) {
  const activeCount = tasks.filter((task) => task.status === "running").length;
  const attentionCount = tasks.filter((task) => task.status === "attention").length;
  const averageProgress = Math.round(tasks.reduce((sum, task) => sum + task.progress, 0) / tasks.length);

  if (orientation === "landscape") {
    return (
      <LandscapeAmbientDashboard
        goal={goal}
        tasks={tasks}
        widgetSizes={widgetSizes}
        anchorCount={anchorCount}
        progress={averageProgress}
        onEditGoal={onEditGoal}
        onTaskAction={onTaskAction}
        onResizeWidget={onResizeWidget}
      />
    );
  }

  return (
    <main className="app-scroll focus-screen">
      <HarborDoodles />
      <div className="focus-intro">
        <div>
          <p className="eyebrow">{getGreeting()} · FOCUS SESSION</p>
          <h1>把注意力留给判断。</h1>
          <p>{activeCount} 个进程正在推进{attentionCount ? `，${attentionCount} 个节点等你` : ""}</p>
        </div>
        <span className="session-duration"><i />42m</span>
      </div>

      <div className="dashboard-layout">
        <section className="goal-card mission-card" aria-labelledby="goal-heading" style={{ viewTransitionName: "anchor-goal" }}>
          <div className="mission-copy">
            <div className="goal-topline">
              <div>
                <p className="section-kicker">ANCHOR MAP · 本次目标</p>
                <h2 id="goal-heading">{goal.title}</h2>
              </div>
              <button className="icon-button subtle" onClick={onEditGoal} aria-label="编辑本次锚点" title="编辑">
                <Pencil size={17} />
              </button>
            </div>
            <p className="goal-note">{goal.note}</p>
            <div className="mission-signal-row">
              <span><i /> {activeCount} 条航线运行中</span>
              <strong>{averageProgress}%</strong>
            </div>
            <div className="goal-meta">
              <span><TimerReset size={14} /> {goal.startedAt} 开始</span>
              <span><MapPin size={14} /> 已投锚 {anchorCount + 1} 次</span>
            </div>
          </div>
          <MissionMap tasks={tasks} progress={averageProgress} />
          <MissionFlowSummary tasks={tasks} />
        </section>

        <div className="harbor-wave-divider" aria-hidden="true">
          <Waves size={84} strokeWidth={1.7} />
          <Waves size={84} strokeWidth={1.7} />
          <Waves size={84} strokeWidth={1.7} />
        </div>

        <section className="task-section" aria-labelledby="task-heading">
          <div className="section-heading-row">
            <div>
              <p className="section-kicker">实时进程</p>
              <h2 id="task-heading">现在发生的事</h2>
            </div>
            <span className="task-heading-actions">
              <span className="live-label"><i /> LIVE</span>
              <button className="widget-layout-button" onClick={onOpenLayout} aria-label="调整进程小组件布局" title="调整小组件布局">
                <LayoutGrid size={15} />
              </button>
            </span>
          </div>
          <TaskWidgetGrid
            tasks={tasks}
            widgetSizes={widgetSizes}
            onOpenTask={onOpenTask}
            onResizeWidget={onResizeWidget}
          />
        </section>

        <div className="focus-footer">
          <div className="anchor-control">
            <button className="anchor-action" onClick={onAnchor} aria-label="投下锚点" title="投锚" data-testid="home-anchor" style={{ viewTransitionName: "anchor-primary-action" }}>
              <AnchorIcon size={27} strokeWidth={2.2} />
              <i aria-hidden="true" />
            </button>
            <span>投锚</span>
          </div>
        </div>
      </div>
    </main>
  );
}

function LandscapeAmbientDashboard({
  goal,
  tasks,
  widgetSizes,
  anchorCount,
  progress,
  onEditGoal,
  onTaskAction,
  onResizeWidget,
}) {
  const [time, setTime] = useState(() =>
    new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false }),
  );
  const attentionTask = tasks.find((task) => task.status === "attention");
  const [inspectedTaskId, setInspectedTaskId] = useState(null);
  const inspectedTask = tasks.find((task) => task.id === inspectedTaskId) || attentionTask || null;
  const runningCount = tasks.filter((task) => task.status === "running").length;
  const queuedCount = tasks.filter((task) => task.status === "queued").length;
  const tickerItems = tasks.slice(0, 4).map((task) => {
    if (task.status === "attention") return `${task.app} · ${task.metric} 个${task.metricLabel}等待判断`;
    if (task.status === "done") return `${task.app} · 已完成 ${task.title}`;
    return `${task.app} · ${task.activity[task.activity.length - 1]}`;
  });

  useEffect(() => {
    const timer = window.setInterval(() => {
      setTime(new Date().toLocaleTimeString("zh-CN", { hour: "2-digit", minute: "2-digit", hour12: false }));
    }, 30000);
    return () => window.clearInterval(timer);
  }, []);

  return (
    <main className={`landscape-ambient-screen ${attentionTask ? "has-attention" : ""}`}>
      <div className="ambient-edge-progress" aria-hidden="true">
        {tasks.slice(0, 4).map((task) => (
          <span data-tone={task.appTone} key={task.id}><i style={{ width: `${task.progress}%` }} /></span>
        ))}
      </div>
      {attentionTask && <i className="ambient-attention-edge" aria-hidden="true" />}

      <header className="ambient-standby-header">
        <div className="ambient-clock">
          <strong>{time}</strong>
          <span><i /> ANCHOR ACTIVE</span>
        </div>
        <div className="ambient-focus-countdown">
          <span>专注中</span>
          <strong>42m</strong>
        </div>
      </header>

      <div className="ambient-workspace">
        <section className="ambient-left-pane" aria-label="进程概览">
          <button
            className="ambient-goal-line"
            onClick={onEditGoal}
            aria-label={`编辑当前目标：${goal.title}`}
            style={{ viewTransitionName: "anchor-goal" }}
          >
            <span className="ambient-goal-mark"><AnchorIcon size={18} /></span>
            <span className="ambient-goal-copy"><small>当前目标 · 已投锚 {anchorCount + 1} 次</small><strong>{goal.title}</strong></span>
            <span className="ambient-overall"><strong>{progress}%</strong><small>总体推进</small></span>
            <ChevronRight size={16} />
          </button>

          <TaskWidgetGrid
            tasks={tasks}
            widgetSizes={widgetSizes}
            onOpenTask={(taskId) => setInspectedTaskId(taskId === attentionTask?.id ? null : taskId)}
            onResizeWidget={onResizeWidget}
            context="ambient"
            attentionPresentation="static"
          />
        </section>

        {inspectedTask ? (
          <AmbientTaskInspector
            task={inspectedTask}
            pendingTask={attentionTask}
            onClose={inspectedTaskId ? () => setInspectedTaskId(null) : null}
            onReturnToDecision={attentionTask && inspectedTask.id !== attentionTask.id ? () => setInspectedTaskId(null) : null}
            onAction={(direction) => {
              onTaskAction(inspectedTask.id, direction);
              setInspectedTaskId(null);
            }}
          />
        ) : (
          <section className="ambient-clear-panel" aria-label="当前工作稳定">
            <AnchorCompanion mood="calm" />
            <p>所有进程保持运行</p>
            <strong>无需处理</strong>
            <small>{runningCount} 个自动推进{queuedCount ? ` · ${queuedCount} 个准备中` : ""}</small>
          </section>
        )}
      </div>

      <div className="ambient-event-ticker" role="status" aria-label={`最新进展：${tickerItems.join("；")}`} title="按住暂停滚动">
        <span className="ambient-ticker-label"><Activity size={14} /> 最新进展</span>
        <div className="ambient-ticker-window">
          <div className="ambient-ticker-track">
            {[0, 1].map((copy) => (
              <span aria-hidden={copy === 1} key={copy}>
                {tickerItems.map((item, index) => <i key={`${copy}-${item}`}>{item}{index < tickerItems.length - 1 ? <b>·</b> : null}</i>)}
              </span>
            ))}
          </div>
        </div>
      </div>
    </main>
  );
}

function AmbientTaskInspector({ task, pendingTask, onClose, onReturnToDecision, onAction }) {
  const StatusIcon = statusIcons[task.status] || Activity;
  const [selectedDirection, setSelectedDirection] = useState("B");
  const needsDecision = task.status === "attention";

  useEffect(() => setSelectedDirection("B"), [task.id]);

  return (
    <section
      className={`ambient-inline-inspector ${needsDecision ? "is-attention" : ""}`}
      data-tone={task.appTone}
      aria-labelledby="ambient-inspector-heading"
      data-testid={`ambient-inspector-${task.id}`}
    >
      <header className="ambient-inspector-header">
        <span className={`app-tile ${task.appTone}`}>{task.appCode}</span>
        <span className="ambient-inspector-app"><small>{task.app}</small><strong><StatusIcon size={13} /> {task.statusLabel}</strong></span>
        {onClose && (
          <button className="ambient-inspector-close" onClick={onClose} aria-label="关闭任务详情" title="关闭">
            <X size={15} />
          </button>
        )}
      </header>

      {onReturnToDecision && pendingTask && (
        <button className="ambient-return-decision" onClick={onReturnToDecision}>
          <CircleAlert size={13} /> 返回 {pendingTask.app} 判断席
        </button>
      )}

      <div className="ambient-inspector-summary">
        <div className={`ambient-inspector-visual ${needsDecision ? "is-storyboard" : ""}`} data-direction={needsDecision ? selectedDirection : undefined}>
          {needsDecision ? (
            <span className="storyboard-preview" aria-hidden="true"><i /><i /><i /></span>
          ) : (
            <><strong>{task.metric}</strong><small>{task.metricLabel}</small></>
          )}
        </div>
        <div>
          {needsDecision && <span className="ambient-inspector-count">{task.metric} {task.metricLabel}</span>}
          <h2 id="ambient-inspector-heading">{task.title}</h2>
          <p>{task.detail}</p>
        </div>
      </div>

      {needsDecision ? (
        <>
          <div className="ambient-inline-directions" role="group" aria-label="选择视觉方向">
            {directionOptions.map((option) => (
              <button
                className={selectedDirection === option.id ? "selected" : ""}
                data-direction={option.id}
                key={option.id}
                onClick={() => setSelectedDirection(option.id)}
                aria-pressed={selectedDirection === option.id}
              >
                <span className="storyboard-preview" aria-hidden="true"><i /><i /><i /></span>
                <strong>{option.id} · {option.title}</strong>
              </button>
            ))}
          </div>
          <button className="ambient-inspector-primary" onClick={() => onAction(selectedDirection)} data-testid="ambient-inline-confirm">
            确认方向 {selectedDirection} <ChevronRight size={17} />
          </button>
        </>
      ) : (
        <>
          <div className="ambient-inspector-progress">
            <span>任务进度</span><i><b style={{ width: `${task.progress}%` }} /></i><strong>{task.progress}%</strong>
          </div>
          <div className="ambient-inspector-activity">
            {task.activity.slice(-2).map((item, index) => <span className={index ? "current" : ""} key={item}><i />{item}</span>)}
          </div>
          <button className="ambient-inspector-primary" onClick={() => onAction("B")}>
            {task.status === "queued" ? "提前运行" : task.status === "done" ? "查看产出" : "在 Mac 上打开"}
            <ChevronRight size={17} />
          </button>
        </>
      )}
    </section>
  );
}

function TaskWidgetGrid({
  tasks,
  widgetSizes,
  onOpenTask,
  onResizeWidget,
  context = "desk",
  attentionPresentation = "focus",
}) {
  const attentionTaskId = tasks.find((task) => task.status === "attention")?.id;
  const shouldFocusAttention = attentionPresentation === "focus";

  return (
    <div
      className={`task-widget-grid is-${context} attention-${attentionPresentation} ${attentionTaskId ? "has-attention" : ""}`}
      data-count={tasks.length}
    >
      {tasks.map((task) => (
        <TaskWidget
          key={task.id}
          task={task}
          size={widgetSizes[task.id] || "2x2"}
          context={context}
          isDecisionFocus={Boolean(shouldFocusAttention && task.id === attentionTaskId)}
          isDeemphasized={Boolean(shouldFocusAttention && attentionTaskId && task.id !== attentionTaskId)}
          onClick={() => onOpenTask(task.id)}
          onResize={(size) => onResizeWidget(task.id, size)}
        />
      ))}
    </div>
  );
}

function TaskWidget({ task, size, context, isDecisionFocus, isDeemphasized, onClick, onResize }) {
  const StatusIcon = statusIcons[task.status] || Activity;
  const dragState = useRef(null);
  const suppressClick = useRef(false);
  const [resizing, setResizing] = useState(false);
  const dimensions = widgetDimensions[size] || widgetDimensions["2x2"];

  const settleResize = (pointerId) => {
    const drag = dragState.current;
    if (!drag || drag.pointerId !== pointerId) return false;
    suppressClick.current = drag.moved;
    dragState.current = null;
    setResizing(false);
    window.setTimeout(() => {
      suppressClick.current = false;
    }, 0);
    return true;
  };

  useEffect(() => {
    if (!resizing) return undefined;
    const finishWindowResize = (event) => settleResize(event.pointerId);
    window.addEventListener("pointerup", finishWindowResize);
    window.addEventListener("pointercancel", finishWindowResize);
    return () => {
      window.removeEventListener("pointerup", finishWindowResize);
      window.removeEventListener("pointercancel", finishWindowResize);
    };
  }, [resizing]);

  const startResize = (event) => {
    if (!event.target.closest(".widget-resize-grip")) return;
    event.preventDefault();
    event.stopPropagation();
    dragState.current = {
      pointerId: event.pointerId,
      startX: event.clientX,
      startY: event.clientY,
      startColumns: dimensions.columns,
      startRows: dimensions.rows,
      lastSize: size,
      moved: false,
    };
    event.currentTarget.setPointerCapture?.(event.pointerId);
    setResizing(true);
  };

  const resizeWidget = (event) => {
    const drag = dragState.current;
    if (!drag || drag.pointerId !== event.pointerId) return;
    const deltaX = event.clientX - drag.startX;
    const deltaY = event.clientY - drag.startY;
    if (!drag.moved && Math.abs(deltaX) < 18 && Math.abs(deltaY) < 18) return;
    drag.moved = true;
    const columns = deltaX > 26 ? 4 : deltaX < -26 ? 2 : drag.startColumns;
    const rows = deltaY > 26 ? 4 : deltaY < -26 ? 2 : drag.startRows;
    const nextSize = `${columns}x${rows}`;
    if (widgetDimensions[nextSize] && nextSize !== drag.lastSize) {
      drag.lastSize = nextSize;
      onResize(nextSize);
    }
  };

  useEffect(() => {
    if (!resizing) return undefined;
    window.addEventListener("pointermove", resizeWidget);
    return () => window.removeEventListener("pointermove", resizeWidget);
  }, [resizing]);

  const finishResize = (event) => {
    if (!settleResize(event.pointerId)) return;
    if (event.currentTarget.hasPointerCapture?.(event.pointerId)) {
      event.currentTarget.releasePointerCapture(event.pointerId);
    }
  };

  const openWidget = () => {
    if (suppressClick.current) return;
    onClick();
  };

  return (
    <button
      className={`task-card task-widget ${resizing ? "is-resizing" : ""} ${isDecisionFocus ? "is-decision-focus" : ""} ${isDeemphasized ? "is-deemphasized" : ""}`}
      data-status={task.status}
      data-task={task.id}
      data-tone={task.appTone}
      data-size={size}
      data-context={context}
      data-testid={`task-widget-${task.id}`}
      style={{
        "--widget-columns": dimensions.columns,
        "--widget-rows": dimensions.rows,
        viewTransitionName: `anchor-task-${task.id}`,
      }}
      onClick={openWidget}
      onPointerDown={startResize}
      onPointerMove={resizeWidget}
      onPointerUp={finishResize}
      onPointerCancel={finishResize}
      onLostPointerCapture={(event) => settleResize(event.pointerId)}
      aria-label={`${task.app}，${task.title}，${task.progress}%，${dimensions.label} 小组件${isDecisionFocus ? "，去选择方向" : ""}`}
    >
      <div className="task-card-top">
        <span className={`app-tile ${task.appTone}`}>{task.appCode}</span>
        <span className="task-status"><StatusIcon size={13} /> {task.statusLabel}</span>
      </div>
      <div className="task-copy">
        <span className="task-app">{task.app}</span>
        <h3>{task.title}</h3>
        <p>{task.detail}</p>
      </div>
      <TaskMiniVisual task={task} />
      {isDecisionFocus && (
        <span className="task-inline-cta" data-testid={`task-cta-${task.id}`} aria-hidden="true">
          <span><CircleAlert size={13} /> 去选择方向</span>
          <ChevronRight size={15} />
        </span>
      )}
      <div className="task-widget-facts">
        <span><TimerReset size={13} /><small>预计</small><strong>{task.eta}</strong></span>
        <span><History size={13} /><small>更新</small><strong>{task.updated}</strong></span>
      </div>
      <div className="task-widget-activity">
        <span className="task-widget-activity-heading">最近活动</span>
        {task.activity.slice(-3).map((item, index) => (
          <span className={index === task.activity.slice(-3).length - 1 ? "current" : ""} key={item}><i />{item}</span>
        ))}
      </div>
      <div className="progress-row">
        <div className="progress-track"><i style={{ width: `${task.progress}%` }} /></div>
        <strong>{task.progress}%</strong>
      </div>
      <span className="widget-resize-readout" aria-hidden="true">{dimensions.label}</span>
      <span className="widget-resize-grip" data-testid={`widget-resize-${task.id}`} title="拖动调整小组件尺寸" aria-hidden="true"><Grip size={14} /></span>
    </button>
  );
}

function MissionMap({ tasks, progress }) {
  return (
    <div className="mission-map" aria-label={`总体推进 ${progress}%，${tasks.length} 个任务节点`}>
      <i className="mission-orbit orbit-outer" />
      <i className="mission-orbit orbit-inner" />
      <span className="mission-core"><AnchorIcon size={23} strokeWidth={2.2} /></span>
      {tasks.slice(0, 4).map((task, index) => (
        <span className={`mission-node node-${index + 1} ${task.appTone}`} key={task.id} title={`${task.app} ${task.progress}%`}>
          <b>{task.appCode}</b>
          <i style={{ height: `${Math.max(16, task.progress)}%` }} />
        </span>
      ))}
      <span className="mission-score"><strong>{progress}%</strong><small>总体推进</small></span>
    </div>
  );
}

function MissionFlowSummary({ tasks }) {
  return (
    <div className="mission-flow-summary" aria-label="主页进程流向摘要">
      <div className="mission-flow-heading">
        <span>进程流向</span>
        <strong>并行效率 2.4×</strong>
      </div>
      <div className="mission-flow-grid">
        {tasks.slice(0, 4).map((task) => (
          <span className={`mission-flow-item ${task.appTone}`} key={task.id}>
            <b>{task.appCode}</b>
            <i><em style={{ width: `${Math.max(12, task.progress)}%` }} /></i>
            <small>{task.progress}%</small>
          </span>
        ))}
      </div>
    </div>
  );
}

function TaskMiniVisual({ task }) {
  const heights = [38, 70, 48, 84, 58, 76, 44, 66];

  return (
    <div className={`task-mini-visual visual-${task.visual || "wave"}`} aria-hidden="true">
      {task.visual === "wave" && (
        <span className="mini-wave">{heights.map((height, index) => <i key={index} style={{ height: `${height}%` }} />)}</span>
      )}
      {task.visual === "frames" && (
        <span className="mini-frames"><i /><i /><i /></span>
      )}
      {task.visual === "orbit" && (
        <span className="mini-orbit">
          <svg viewBox="0 0 42 42" aria-hidden="true">
            <circle cx="21" cy="21" r="16" />
            <circle className="current" cx="21" cy="21" r="16" pathLength="100" strokeDasharray={`${task.progress} 100`} />
          </svg>
          <i />
        </span>
      )}
      {task.visual === "timeline" && (
        <span className="mini-timeline"><i /><i /><i /><i /><i /></span>
      )}
      <span className="mini-metric"><strong>{task.metric || `${task.progress}%`}</strong><small>{task.metricLabel || "当前进度"}</small></span>
    </div>
  );
}

function AwayDashboard({ goal, tasks, widgetSizes, awayStarted, onOpenTask, onResizeWidget, onOpenLayout }) {
  const attentionCount = tasks.filter((task) => task.status === "attention").length;
  const minutes = awayStarted ? Math.max(1, Math.floor((Date.now() - awayStarted) / 60000)) : 1;

  return (
    <main className="app-scroll away-screen unified-widget-away">
      <div className="away-heading">
        <div className="away-live"><i /> 离开 {minutes} 分钟</div>
        <h1>工作仍在向前。</h1>
        <p>Anchor 只把需要判断的节点带到你面前。</p>
      </div>

      <section className="away-summary">
        <div className="away-goal">
          <span className="section-kicker">CURRENT ANCHOR · 当前目标</span>
          <strong>{goal.title}</strong>
          <small>{tasks.filter((task) => task.status === "running").length} 个进程保持运行</small>
        </div>
        <div className="away-route-pulse" aria-label="远程任务进度">
          {tasks.map((task) => (
            <span className={task.appTone} key={task.id} title={`${task.app} ${task.progress}%`}>
              <b>{task.appCode}</b><i><em style={{ width: `${task.progress}%` }} /></i>
            </span>
          ))}
        </div>
      </section>

      <section className="away-group away-widget-section">
        <div className="section-heading-row compact">
          <div><p className="section-kicker">远程进程</p><h2>持续同步的工作</h2></div>
          <span className="task-heading-actions">
            <span className="away-widget-count">{tasks.length} 个 · {attentionCount} 待判断</span>
            <button className="widget-layout-button" onClick={onOpenLayout} aria-label="调整进程小组件布局" title="调整小组件布局">
              <LayoutGrid size={15} />
            </button>
          </span>
        </div>
        <TaskWidgetGrid
          tasks={tasks}
          widgetSizes={widgetSizes}
          context="away"
          onOpenTask={onOpenTask}
          onResizeWidget={onResizeWidget}
        />
      </section>
    </main>
  );
}

function InsightsPage({
  tasks,
  anchorRecords,
  successfulReturns,
  completed,
  onBack,
  onNewAnchor,
  onMemoryAction,
}) {
  const finished = tasks.filter((task) => task.status === "done").length;
  const average = Math.round(tasks.reduce((sum, task) => sum + task.progress, 0) / tasks.length);
  const latestAnchor = anchorRecords[0];

  return (
    <main className="app-scroll insight-screen">
      <div className="subpage-title">
        <button className="icon-button" onClick={onBack} aria-label="返回总览" title="返回">
          <ArrowLeft size={19} />
        </button>
        <div>
          <p className="eyebrow">{completed ? "本次工作 · 已保存" : "工作脉络"}</p>
          <h1>{completed ? "这段工作已经收好" : "你的注意力去了哪里"}</h1>
        </div>
      </div>

      {completed && (
        <section className="completion-banner">
          <span className="completion-mark"><CheckCircle2 size={24} /></span>
          <div><strong>目标、进程与判断均已归档</strong><p>下次打开 Anchor 时，可以从这一刻继续。</p></div>
          <button onClick={onNewAnchor}><Plus size={17} /><span>新锚点</span></button>
        </section>
      )}

      <section className="metric-strip" aria-label="本次工作数据">
        <Metric value="42m" label="专注时长" />
        <Metric value={`${average}%`} label="整体推进" />
        <Metric value={`${finished}/4`} label="已完成" />
      </section>

      <section className="flow-section">
        <div className="section-heading-row">
          <div>
            <p className="section-kicker">最近 30 分钟</p>
            <h2>进程流向</h2>
          </div>
          <Gauge size={19} />
        </div>
        <div className="flow-chart-shell">
          <div className="flow-time-axis" aria-hidden="true"><span>14:10</span><span>14:25</span><span>14:40</span></div>
          <div className="flow-chart" aria-label="任务并行进度图">
            {tasks.map((task) => (
              <div className="flow-row" data-tone={task.appTone} key={task.id}>
                <span><i className={`flow-app-dot ${task.appTone}`} />{task.app}</span>
                <i><b className={task.appTone} style={{ width: `${Math.max(12, task.progress)}%` }} /></i>
                <strong>{task.progress}%</strong>
              </div>
            ))}
          </div>
          <div className="flow-legend"><span><i />自动推进</span><span><i />等待判断</span><strong>并行效率 2.4×</strong></div>
        </div>
      </section>

      <section className="context-section">
        <div className="section-heading-row">
          <div>
            <p className="section-kicker">Anchor 记忆</p>
            <h2>可恢复的上下文</h2>
          </div>
          <History size={19} />
        </div>
        <div className="memory-list">
          <button className="memory-row" onClick={() => onMemoryAction("返航记录已定位到本次工作")}>
            <span className="memory-icon soft-blue"><RotateCcw size={18} /></span>
            <span><strong>{successfulReturns} 次顺利返航</strong><small>平均 4 分钟恢复工作状态</small></span>
            <ChevronRight size={17} />
          </button>
          {latestAnchor && (
            <button className="memory-row" onClick={() => onMemoryAction("已定位到最近一次投锚记录")}>
              <span className="memory-icon soft-coral"><MapPin size={18} /></span>
              <span><strong>最近一次投锚 · {latestAnchor.createdAt}</strong><small>{latestAnchor.note}</small></span>
              <ChevronRight size={17} />
            </button>
          )}
          <button className="memory-row" onClick={() => onMemoryAction("上下文完整性检查已通过")}>
            <span className="memory-icon soft-green"><ShieldCheck size={18} /></span>
            <span><strong>本次上下文完整</strong><small>目标、进程与判断节点均已保存</small></span>
            <Check size={17} />
          </button>
        </div>
      </section>

      <section className="attention-note">
        <Sparkles size={19} />
        <div><strong>判断集中在分镜阶段</strong><p>下一次可先确定视觉方向，再并行启动视频生成。</p></div>
      </section>

    </main>
  );
}

function Metric({ value, label }) {
  return <div><strong>{value}</strong><span>{label}</span></div>;
}

function ProfileMetric({ value, label, trend, fill, tone, onClick }) {
  return (
    <button className="profile-stat" data-tone={tone} onClick={onClick} aria-label={`${label}，${value}，${trend}`}>
      <span className="profile-stat-heading"><strong>{value}</strong><ChevronRight size={14} /></span>
      <span>{label}</span>
      <i aria-hidden="true"><em style={{ width: fill }} /></i>
      <small>{trend}</small>
    </button>
  );
}

function ProfilePage({
  settings,
  anchorCount,
  sessionComplete,
  tasks,
  anchorRecords,
  successfulReturns,
  onChangeSetting,
  onBack,
  onAccount,
  onOpenDetail,
}) {
  const averageProgress = Math.round(tasks.reduce((sum, task) => sum + task.progress, 0) / tasks.length);
  const finished = tasks.filter((task) => task.status === "done").length;
  const running = tasks.filter((task) => task.status === "running").length;
  const attention = tasks.filter((task) => task.status === "attention").length;
  const latestAnchor = anchorRecords[0];

  return (
    <main className="profile-screen app-scroll">
      <div className="profile-nav">
        <button className="icon-button" onClick={onBack} aria-label="返回" title="返回"><ArrowLeft size={19} /></button>
        <span>我的</span>
        <button className="icon-button" onClick={onAccount} aria-label="账户设置" title="账户设置"><Settings2 size={19} /></button>
      </div>

      <section className="profile-identity">
        <div className="profile-avatar"><AnchorIcon size={27} /></div>
        <div className="profile-identity-copy">
          <p className="profile-kicker">PERSONAL ANCHOR</p>
          <h1>我的 Anchor</h1>
          <span className="profile-sync-badge"><Wifi size={13} />{sessionComplete ? "本次工作已收好" : "上下文同步稳定"}</span>
        </div>
        <div className="profile-device-state"><strong>1</strong><small>Mac 在线</small></div>
      </section>

      <section className="profile-stats" aria-label="Anchor 累计数据">
        <ProfileMetric value="18h" label="已守住的专注" trend="本周 +2h 18m" fill="72%" tone="coral" onClick={() => onOpenDetail("profile-focus")} />
        <ProfileMetric value={String(23 + anchorCount)} label="保存的上下文" trend="完整度 96%" fill="96%" tone="blue" onClick={() => onOpenDetail("profile-contexts")} />
        <ProfileMetric value={String(12 + (sessionComplete ? 1 : 0))} label="完成的锚点" trend="连续 4 周" fill="64%" tone="green" onClick={() => onOpenDetail("profile-anchors")} />
      </section>

      <button className="profile-session-data" onClick={() => onOpenDetail("profile-session")} aria-label="打开本次工作完整脉络">
        <div className="profile-session-heading">
          <div>
            <p className="section-kicker">本次工作数据</p>
            <h2>{sessionComplete ? "已保存的工作脉络" : "正在运行的工作"}</h2>
          </div>
          <span>{running} 运行 · {attention} 待判断 <ChevronRight size={14} /></span>
        </div>
        <div className="metric-strip profile-session-metrics">
          <Metric value="42m" label="专注时长" />
          <Metric value={`${averageProgress}%`} label="整体推进" />
          <Metric value={`${finished}/4`} label="已完成" />
        </div>
        <div className="profile-context-line">
          <span><RotateCcw size={14} /> {successfulReturns} 次顺利返航</span>
          <span><Gauge size={14} /> 并行效率 2.4×</span>
          <span><MapPin size={14} /> {latestAnchor ? "最近投锚 · 刚刚" : "当前锚点已保持"}</span>
        </div>
      </button>

      <section className="profile-memory-section" aria-labelledby="profile-memory-heading">
        <div className="profile-memory-heading">
          <div><p className="section-kicker">记忆航迹</p><h2 id="profile-memory-heading">最近被 Anchor 接住的事</h2></div>
          <span>本周 7 条</span>
        </div>
        <div className="profile-memory-track">
          <button className="profile-memory-event" data-tone="green" onClick={() => onOpenDetail("profile-return")}>
            <span className="profile-memory-mark"><RotateCcw size={16} /></span>
            <span className="profile-memory-copy"><small>返航记忆 · 今天 14:32</small><strong>18 分钟后，重新接住工作</strong><p>目标、4 个进程与待判断节点完整恢复。</p></span>
            <span className="profile-memory-value">96%<ChevronRight size={14} /></span>
          </button>
          <button className="profile-memory-event" data-tone="coral" onClick={() => onOpenDetail("profile-decision")}>
            <span className="profile-memory-mark"><CheckCircle2 size={16} /></span>
            <span className="profile-memory-copy"><small>关键判断 · 今天 14:21</small><strong>故事分镜采用方向 B</strong><p>镜头描述已继续生成，两个后续进程解除等待。</p></span>
            <span className="profile-memory-value">B<ChevronRight size={14} /></span>
          </button>
          <button className="profile-memory-event" data-tone="blue" onClick={() => onOpenDetail("profile-snapshot")}>
            <span className="profile-memory-mark"><Layers3 size={16} /></span>
            <span className="profile-memory-copy"><small>上下文快照 · {latestAnchor ? "刚刚" : "今天 14:10"}</small><strong>Anchor 产宣片 · 完整脉络</strong><p>{latestAnchor?.note || "目标、进程流向与关键判断已形成可恢复快照。"}</p></span>
            <span className="profile-memory-value">4/4<ChevronRight size={14} /></span>
          </button>
        </div>
      </section>

      <section className="settings-section">
        <p className="section-kicker">工作方式</p>
        <ToggleRow
          icon={Activity}
          title="实时活动"
          subtitle="在锁屏显示关键进度"
          checked={settings.liveActivity}
          onChange={() => onChangeSetting("liveActivity")}
        />
        <ToggleRow
          icon={Bell}
          title="克制提醒"
          subtitle="仅在需要判断或失败时提醒"
          checked={settings.quietMode}
          onChange={() => onChangeSetting("quietMode")}
        />
        <ToggleRow
          icon={Zap}
          title="触感反馈"
          subtitle="确认与返航时提供轻触感"
          checked={settings.haptics}
          onChange={() => onChangeSetting("haptics")}
        />
      </section>

      <section className="settings-section">
        <p className="section-kicker">连接与隐私</p>
        <SettingsRow icon={Cloud} title="iCloud 同步" value="已开启" onClick={() => onOpenDetail("icloud")} />
        <SettingsRow icon={ShieldCheck} title="数据与隐私" value="仅本机" onClick={() => onOpenDetail("privacy")} />
        <SettingsRow icon={Layers3} title="已连接来源" value="4 个" onClick={() => onOpenDetail("sources")} />
      </section>

      <p className="version-label">Anchor Prototype · iOS</p>
    </main>
  );
}

function ToggleRow({ icon: Icon, title, subtitle, checked, onChange }) {
  return (
    <div className="setting-row">
      <span className="setting-icon"><Icon size={18} /></span>
      <span className="setting-copy"><strong>{title}</strong><small>{subtitle}</small></span>
      <button
        className={`toggle ${checked ? "on" : ""}`}
        onClick={onChange}
        role="switch"
        aria-checked={checked}
        aria-label={title}
      ><i /></button>
    </div>
  );
}

function SettingsRow({ icon: Icon, title, value, onClick }) {
  return (
    <button className="setting-row setting-link" onClick={onClick}>
      <span className="setting-icon"><Icon size={18} /></span>
      <span className="setting-copy"><strong>{title}</strong></span>
      <span className="setting-value">{value}</span>
      <ChevronRight size={17} />
    </button>
  );
}

function SetupScreen({ goal, tasks, onCancel, onComplete, showCancel }) {
  const [title, setTitle] = useState(goal.title);
  const [note, setNote] = useState(goal.note);
  const [draftTasks, setDraftTasks] = useState(tasks.map((task) => task.title));
  const [recording, setRecording] = useState(false);
  const [newTask, setNewTask] = useState("");

  useEffect(() => {
    if (!recording) return undefined;
    const timer = window.setTimeout(() => {
      setNote("今天完成 60 秒成片：先定脚本和分镜，并行生成镜头，最后由我完成节奏与审美判断。");
      setRecording(false);
    }, 1600);
    return () => window.clearTimeout(timer);
  }, [recording]);

  const updateTask = (index, value) => {
    setDraftTasks((current) => current.map((item, itemIndex) => (itemIndex === index ? value : item)));
  };

  const removeTask = (index) => {
    setDraftTasks((current) => current.filter((_, itemIndex) => itemIndex !== index));
  };

  const addTask = () => {
    const trimmed = newTask.trim();
    if (!trimmed || draftTasks.length >= 6) return;
    setDraftTasks((current) => [...current, trimmed]);
    setNewTask("");
  };

  const canStart = title.trim() && note.trim() && draftTasks.some((item) => item.trim());

  return (
    <div className="setup-screen app-scroll">
      <StatusBar />
      <div className="setup-nav">
        {showCancel ? (
          <button className="icon-button" onClick={onCancel} aria-label="取消" title="取消"><X size={20} /></button>
        ) : <span />}
        <span className="setup-step">新工作</span>
        <span className="setup-count">01</span>
      </div>

      <header className="setup-heading">
        <div className="setup-heading-copy">
          <span className="setup-brand"><AnchorIcon size={20} /></span>
          <p className="eyebrow">建立锚点</p>
          <h1>先记住为什么，<br />再开始做什么。</h1>
        </div>
        <div className="setup-brief-stats" aria-label="锚点准备状态">
          <span><strong>{draftTasks.length}</strong><small>并行进程</small></span>
          <span><strong>{note.trim() ? "✓" : "—"}</strong><small>完成标准</small></span>
        </div>
      </header>

      <section className="setup-form">
        <label className="field-label" htmlFor="goal-title">这次要完成什么</label>
        <input id="goal-title" value={title} onChange={(event) => setTitle(event.target.value)} />

        <div className="field-label-row">
          <label className="field-label" htmlFor="goal-note">完成时应该是什么样</label>
          <button
            className={`voice-button ${recording ? "recording" : ""}`}
            onClick={() => setRecording((value) => !value)}
            aria-label={recording ? "停止语音记录" : "开始语音记录"}
            title="语音记录"
          >{recording ? <Pause size={16} /> : <Mic size={16} />}</button>
        </div>
        <textarea id="goal-note" value={note} onChange={(event) => setNote(event.target.value)} rows={4} />
        {recording && <div className="voice-wave" aria-live="polite"><i /><i /><i /><i /><i /><span>正在听...</span></div>}
      </section>

      <section className="setup-tasks">
        <div className="section-heading-row compact">
          <div><p className="section-kicker">并行进程</p><h2>准备同步的任务</h2></div>
          <span>{draftTasks.length}/6</span>
        </div>
        <div className="draft-task-list">
          {draftTasks.map((task, index) => (
            <div
              className="draft-task"
              data-tone={tasks[index]?.appTone || ["coral", "blue", "cyan", "ink"][index % 4]}
              key={`draft-${index}`}
            >
              <span className="draft-task-index">{String(index + 1).padStart(2, "0")}</span>
              <input
                value={task}
                onChange={(event) => updateTask(index, event.target.value)}
                aria-label={`任务 ${index + 1}`}
              />
              <button onClick={() => removeTask(index)} aria-label={`删除任务 ${index + 1}`} title="删除">
                <Trash2 size={16} />
              </button>
            </div>
          ))}
        </div>
        {draftTasks.length < 6 && (
          <div className="add-task-row">
            <input
              value={newTask}
              onChange={(event) => setNewTask(event.target.value)}
              onKeyDown={(event) => event.key === "Enter" && addTask()}
              placeholder="添加另一个进程"
              aria-label="新任务名称"
            />
            <button className="icon-button" onClick={addTask} aria-label="添加任务" title="添加"><Plus size={18} /></button>
          </div>
        )}
      </section>

      <div className="setup-submit-dock">
        <button
          className="primary-button setup-submit"
          disabled={!canStart}
          onClick={() =>
            onComplete({
              nextGoal: { title: title.trim(), note: note.trim(), startedAt: "现在" },
              nextTaskNames: draftTasks.filter((item) => item.trim()),
            })
          }
        >
          <Play size={18} fill="currentColor" />
          开始锚定
        </button>
      </div>
      <HomeIndicator />
    </div>
  );
}

function BottomSheet({ title, onClose, children, className = "", layerClassName = "" }) {
  return (
    <div className={`modal-layer ${layerClassName}`} role="presentation" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className={`bottom-sheet ${className}`} role="dialog" aria-modal="true" aria-label={title}>
        <div className="sheet-handle" />
        <div className="sheet-nav">
          <strong>{title}</strong>
          <button className="icon-button" onClick={onClose} aria-label="关闭" title="关闭"><X size={19} /></button>
        </div>
        <div className="sheet-content">{children}</div>
      </section>
    </div>
  );
}

function AnchorCaptureSheet({ goal, tasks, origin, recentRecord, onClose, onSave }) {
  const [note, setNote] = useState("");
  const [recording, setRecording] = useState(false);
  const runningCount = tasks.filter((task) => task.status === "running").length;
  const attentionCount = tasks.filter((task) => task.status === "attention").length;

  useEffect(() => {
    if (!recording) return undefined;
    const timer = window.setTimeout(() => {
      setNote(
        origin === "return"
          ? "先确认分镜方向，再复核 58 秒脚本，随后回到剪辑时间线。"
          : "分镜采用方向 B；等 Seedance 完成后，先复核镜头 04 的运动稳定性。",
      );
      setRecording(false);
    }, 1500);
    return () => window.clearTimeout(timer);
  }, [origin, recording]);

  return (
    <BottomSheet
      title="投下锚点"
      onClose={onClose}
      className="anchor-capture-sheet"
      layerClassName={origin === "return" ? "modal-layer-over-return" : ""}
    >
      <header className="anchor-capture-heading">
        <span className="anchor-capture-mark"><AnchorIcon size={25} strokeWidth={2.2} /></span>
        <div>
          <p className="eyebrow">{origin === "return" ? "返航记录" : "当前工作"}</p>
          <h2>记下此刻，继续向前。</h2>
        </div>
      </header>

      <div className="anchor-context-strip" aria-label="当前工作快照">
        <div>
          <MapPin size={16} />
          <span><small>当前目标</small><strong>{goal.title}</strong></span>
        </div>
        <div>
          <Activity size={16} />
          <span><small>进程快照</small><strong>{runningCount} 运行 · {attentionCount} 待判断</strong></span>
        </div>
      </div>

      <div className="anchor-capture-form">
        <label htmlFor="anchor-note">此刻要记住的事</label>
        <textarea
          id="anchor-note"
          value={note}
          onChange={(event) => setNote(event.target.value)}
          maxLength={140}
          rows={4}
          placeholder="判断、下一步，或需要保留的上下文"
          autoFocus
        />
        <div className="anchor-capture-meta">
          <button
            className={`anchor-voice-button ${recording ? "recording" : ""}`}
            onClick={() => setRecording((current) => !current)}
            aria-label={recording ? "停止语音记录" : "开始语音记录"}
          >
            {recording ? <Pause size={16} /> : <Mic size={16} />}
            {recording ? "停止" : "语音记录"}
          </button>
          <span>{recording ? "正在听..." : `${note.length}/140`}</span>
        </div>
      </div>

      {recentRecord && (
        <div className="recent-anchor-record">
          <span><CheckCircle2 size={15} /> 最近一次 · {recentRecord.createdAt}</span>
          <p>{recentRecord.note}</p>
        </div>
      )}

      <button className="primary-button" disabled={!note.trim()} onClick={() => onSave(note)}>
        <AnchorIcon size={18} /> 投下锚点
      </button>
    </BottomSheet>
  );
}

function FactRow({ icon: Icon, label, value }) {
  return (
    <div className="fact-row">
      <span><Icon size={17} /> {label}</span>
      <strong>{value}</strong>
    </div>
  );
}

function TaskSheet({ task, overReturn = false, onClose, onAction }) {
  const StatusIcon = statusIcons[task.status] || Activity;
  const [selectedDirection, setSelectedDirection] = useState("B");
  const actionLabel = task.status === "attention"
    ? `确认方向 ${selectedDirection}`
    : task.status === "queued"
      ? "提高优先级"
      : task.status === "done"
        ? "查看产出"
        : "在 Mac 上打开";

  return (
    <BottomSheet
      title={task.app}
      onClose={onClose}
      className="task-sheet"
      layerClassName={overReturn ? "modal-layer-over-return" : ""}
    >
      <div className="task-sheet-heading">
        <span className={`app-tile large ${task.appTone}`}>{task.appCode}</span>
        <div><span className={`sheet-status ${task.status}`}><StatusIcon size={14} /> {task.statusLabel}</span><h2>{task.title}</h2></div>
      </div>
      <div className="task-sheet-visual" data-tone={task.appTone}><TaskMiniVisual task={task} /></div>
      {task.status === "attention" && (
        <section className="decision-panel" aria-labelledby="direction-heading">
          <div className="decision-panel-heading">
            <div><p className="section-kicker">需要你的判断</p><h3 id="direction-heading">选择视觉方向</h3></div>
            <span>{directionOptions.findIndex((option) => option.id === selectedDirection) + 1} / 3</span>
          </div>
          <div className="direction-options">
            {directionOptions.map((option) => (
              <button
                className={selectedDirection === option.id ? "selected" : ""}
                data-direction={option.id}
                key={option.id}
                onClick={() => setSelectedDirection(option.id)}
                aria-pressed={selectedDirection === option.id}
              >
                <span className="storyboard-preview" aria-hidden="true"><i /><i /><i /></span>
                <span className="direction-copy"><strong>{option.id} · {option.title}</strong><small>{option.note}</small></span>
                <span className="direction-check"><Check size={13} /></span>
              </button>
            ))}
          </div>
        </section>
      )}
      {task.status === "attention" && (
        <button className="primary-button decision-confirm" onClick={() => onAction(selectedDirection)}>
          {actionLabel}<ChevronRight size={18} />
        </button>
      )}
      <div className="task-progress-large">
        <div><span>任务进度</span><strong>{task.progress}%</strong></div>
        <i><b style={{ width: `${task.progress}%` }} /></i>
      </div>
      <div className="task-detail-block">
        <p className="section-kicker">当前状态</p>
        <strong>{task.detail}</strong>
        <div><span><TimerReset size={14} /> {task.eta}</span><span><Cloud size={14} /> {task.updated}</span></div>
      </div>
      <div className="activity-list">
        <p className="section-kicker">活动记录</p>
        {task.activity.map((item, index) => (
          <div className="activity-row" key={item}>
            <i className={index === task.activity.length - 1 ? "current" : ""} />
            <span>{item}</span>
            {index < task.activity.length - 1 && <Check size={14} />}
          </div>
        ))}
      </div>
      {task.status !== "attention" && (
        <button className="primary-button" onClick={() => onAction(selectedDirection)}>{actionLabel}<ChevronRight size={18} /></button>
      )}
    </BottomSheet>
  );
}

function GoalSheet({ goal, onClose, onSave }) {
  const [title, setTitle] = useState(goal.title);
  const [note, setNote] = useState(goal.note);
  const addNoteCue = (cue) => setNote((current) => `${current.trimEnd()}${current.trim() ? "\n" : ""}${cue}`);
  return (
    <BottomSheet title="编辑本次锚点" onClose={onClose}>
      <div className="edit-anchor-hero">
        <span><AnchorIcon size={22} /></span>
        <div><p>ANCHOR MAP</p><strong>让所有进程继续围绕同一个完成标准。</strong></div>
      </div>
      <div className="edit-fields">
        <label htmlFor="edit-goal-title">目标</label>
        <input id="edit-goal-title" value={title} onChange={(event) => setTitle(event.target.value)} />
        <label htmlFor="edit-goal-note">完成标准</label>
        <textarea id="edit-goal-note" rows={3} value={note} onChange={(event) => setNote(event.target.value)} />
        <div className="edit-note-tools" role="group" aria-label="快速补充完成标准">
          <button onClick={() => addNoteCue("关键判断：")}>记录判断</button>
          <button onClick={() => addNoteCue("下一步：")}>补充下一步</button>
          <button onClick={() => addNoteCue("完成标准：")}>收束标准</button>
        </div>
      </div>
      <button className="primary-button" onClick={() => onSave({ ...goal, title: title.trim(), note: note.trim() })}>
        <Check size={18} /> 保存锚点
      </button>
    </BottomSheet>
  );
}

function NotificationsSheet({ items, onClose, onOpen }) {
  const unreadCount = items.filter((item) => item.unread).length;
  return (
    <BottomSheet title="通知" onClose={onClose} className="notification-sheet">
      <div className="notification-summary">
        <span><Bell size={21} /></span>
        <div><p>克制提醒</p><strong>{unreadCount ? `${unreadCount} 个节点需要留意` : "当前没有待处理节点"}</strong><small>只呈现判断、失败与关键完成</small></div>
      </div>
      <div className="notification-list">
        {items.map((item) => (
          <button
            className={`notification-item ${item.unread ? "unread" : ""}`}
            data-app={item.app.toLowerCase()}
            key={item.id}
            onClick={() => onOpen(item)}
          >
            <span className="notification-app">{item.app.slice(0, 1)}</span>
            <span><strong>{item.title}</strong><p>{item.body}</p><small>{item.time}</small></span>
            <ChevronRight className="notification-chevron" size={16} />
            {item.unread && <i />}
          </button>
        ))}
      </div>
    </BottomSheet>
  );
}

function ProfileDetailSheet({
  type,
  goal,
  tasks,
  anchorRecords,
  successfulReturns,
  sessionComplete,
  onClose,
  onManage,
  onFinish,
}) {
  const averageProgress = Math.round(tasks.reduce((sum, task) => sum + task.progress, 0) / tasks.length);
  const running = tasks.filter((task) => task.status === "running").length;
  const attention = tasks.filter((task) => task.status === "attention").length;
  const latestAnchor = anchorRecords[0];

  if (type === "profile-session") {
    return (
      <BottomSheet title="本次工作详情" onClose={onClose} className="profile-detail-sheet session-detail-sheet">
        <section className="profile-detail-hero" data-tone="session">
          <div className="profile-detail-hero-heading">
            <span className="profile-detail-hero-icon"><Activity size={22} /></span>
            <div><p>CURRENT ANCHOR</p><h2>{goal.title}</h2></div>
            <strong>{averageProgress}%</strong>
          </div>
          <p className="profile-detail-hero-note">{goal.note}</p>
          <div className="profile-detail-session-state">
            <span><i /> {running} 个进程运行中</span>
            <span>{attention} 个节点待判断</span>
            <span>{sessionComplete ? "已保存" : "已同步"}</span>
          </div>
        </section>

        <div className="profile-detail-metrics">
          <span><strong>42m</strong><small>连续专注</small></span>
          <span><strong>2.4×</strong><small>并行效率</small></span>
          <span><strong>{successfulReturns}</strong><small>顺利返航</small></span>
        </div>

        <section className="profile-detail-section">
          <div className="profile-detail-section-heading"><div><p>PROCESS PULSE</p><h3>四条进程流向</h3></div><span>实时</span></div>
          <div className="profile-task-pulses">
            {tasks.map((task) => (
              <div className="profile-task-pulse" data-tone={task.appTone} key={task.id}>
                <b>{task.appCode}</b>
                <span><strong>{task.title}</strong><small>{task.app} · {task.statusLabel}</small></span>
                <i><em style={{ width: `${task.progress}%` }} /></i>
                <strong>{task.progress}%</strong>
              </div>
            ))}
          </div>
        </section>

        <section className="profile-detail-section">
          <div className="profile-detail-section-heading"><div><p>MEMORY TRACE</p><h3>这段工作的关键记忆</h3></div></div>
          <div className="profile-detail-event-list compact">
            <div><time>14:32</time><i data-tone="green" /><span><strong>顺利返航</strong><small>18 分钟离开期间的变化已恢复</small></span></div>
            <div><time>14:21</time><i data-tone="coral" /><span><strong>确认故事分镜方向 B</strong><small>解除两个后续进程的等待</small></span></div>
            <div><time>14:10</time><i data-tone="blue" /><span><strong>建立本次 Anchor</strong><small>{latestAnchor?.note || "目标与四个工作来源完成绑定"}</small></span></div>
          </div>
        </section>

        <div className="profile-session-actions">
          <button className="secondary-button" onClick={onManage}><ListChecks size={17} /> 管理进程</button>
          <button className="finish-session-button" onClick={onFinish}><FileCheck2 size={17} /> 结束工作</button>
        </div>
      </BottomSheet>
    );
  }

  const details = {
    "profile-focus": {
      title: "专注历史",
      icon: TimerReset,
      tone: "coral",
      kicker: "FOCUS ARCHIVE · 近 30 天",
      value: "18h",
      headline: "专注不是时长，\n是连续做对判断。",
      subline: "本周较上周多守住 2h 18m",
      bars: [34, 48, 38, 72, 61, 84, 68, 92, 76, 88, 64, 96],
      events: [
        ["今天", "42 分钟 · Anchor 产宣片", "2 个关键判断，4 个并行进程"],
        ["昨天", "1 小时 16 分 · 发布页改版", "最长连续判断 38 分钟"],
        ["周六", "58 分钟 · 产品叙事", "完成 1 次无损返航"],
      ],
    },
    "profile-contexts": {
      title: "保存的上下文",
      icon: Layers3,
      tone: "blue",
      kicker: "CONTEXT VAULT · 全部记忆",
      value: String(23 + anchorRecords.length),
      headline: "每一次离开，\n都有完整世界可返回。",
      subline: "平均上下文完整度 96%",
      bars: [74, 88, 82, 96, 91, 100, 86, 94, 97, 93, 100, 96],
      events: [
        ["刚刚", "Anchor 产宣片", "目标、4 个进程与 3 个判断已保存"],
        ["昨天", "发布页改版", "Figma、文案与实现状态已保存"],
        ["7 月 30 日", "产品叙事梳理", "12 条思路与最终取舍已保存"],
      ],
    },
    "profile-anchors": {
      title: "完成的锚点",
      icon: AnchorIcon,
      tone: "green",
      kicker: "ANCHOR LOG · 连续 4 周",
      value: String(12 + (sessionComplete ? 1 : 0)),
      headline: "完成不是清空，\n而是把脉络收好。",
      subline: "本月完成率 86%",
      bars: [22, 42, 38, 58, 52, 70, 66, 78, 72, 84, 88, 86],
      events: [
        [sessionComplete ? "今天" : "进行中", "Anchor 产宣片", `${averageProgress}% 推进 · ${running} 个进程运行中`],
        ["昨天", "发布页改版", "1h 16m · 完成 6 个关键节点"],
        ["7 月 30 日", "产品叙事梳理", "58m · 保存最终叙事结构"],
      ],
    },
    "profile-return": {
      title: "返航记忆",
      icon: RotateCcw,
      tone: "green",
      kicker: "RETURN MEMORY · 今天 14:32",
      value: "96%",
      headline: "18 分钟之后，\n工作仍停在正确的位置。",
      subline: `${successfulReturns} 次返航 · 平均恢复 11 秒`,
      bars: [92, 94, 88, 96, 95, 100, 91, 96, 98, 94, 97, 96],
      events: [
        ["14:32", "检测到返回", "目标与任务状态完成对齐"],
        ["14:33", "恢复待判断节点", "故事分镜方向等待你的确认"],
        ["14:33", "继续工作", "四条进程从同一上下文继续"],
      ],
    },
    "profile-decision": {
      title: "关键判断",
      icon: CheckCircle2,
      tone: "coral",
      kicker: "DECISION TRACE · 今天 14:21",
      value: "B",
      headline: "采用产品进入画面，\n再切到使用者视角。",
      subline: "方向确认后，2 个后续进程解除等待",
      bars: [18, 22, 30, 34, 48, 55, 63, 72, 78, 84, 92, 100],
      events: [
        ["判断前", "Gemini 等待确认", "三个故事方向已完成候选分镜"],
        ["14:21", "你选择方向 B", "产品叙事更直接，节奏更清晰"],
        ["判断后", "镜头描述继续生成", "Final Cut 已收到新的剪辑顺序"],
      ],
    },
    "profile-snapshot": {
      title: "上下文快照",
      icon: ShieldCheck,
      tone: "blue",
      kicker: "CONTEXT SNAPSHOT · 今天 14:10",
      value: "4/4",
      headline: "目标、进程、判断与位置，\n都在同一张记忆里。",
      subline: latestAnchor?.note || "快照完整性检查已通过",
      bars: [100, 100, 96, 100, 92, 100, 100, 96, 100, 100, 96, 100],
      events: [
        ["目标", goal.title, goal.note],
        ["进程", "4 个来源完成绑定", `${running} 运行 · ${attention} 待判断`],
        ["位置", "当前锚点已保持", "返航时将从关键判断继续"],
      ],
    },
  };
  const detail = details[type] || details["profile-focus"];
  const Icon = detail.icon;

  return (
    <BottomSheet title={detail.title} onClose={onClose} className="profile-detail-sheet">
      <section className="profile-detail-hero" data-tone={detail.tone}>
        <div className="profile-detail-hero-heading">
          <span className="profile-detail-hero-icon"><Icon size={22} /></span>
          <div><p>{detail.kicker}</p><strong>{detail.value}</strong></div>
        </div>
        <h2>{detail.headline.split("\n").map((line, index) => <span key={line}>{line}{index === 0 && <br />}</span>)}</h2>
        <p className="profile-detail-hero-note">{detail.subline}</p>
      </section>
      <section className="profile-detail-section profile-detail-chart-section">
        <div className="profile-detail-section-heading"><div><p>TREND</p><h3>最近 12 次记录</h3></div><span>稳定向上</span></div>
        <div className="profile-detail-chart" aria-label="最近十二次记录趋势">
          {detail.bars.map((height, index) => <i key={index} style={{ height: `${height}%` }} />)}
        </div>
      </section>
      <section className="profile-detail-section">
        <div className="profile-detail-section-heading"><div><p>RECENT</p><h3>最近记录</h3></div></div>
        <div className="profile-detail-event-list">
          {detail.events.map(([time, title, copy], index) => (
            <div key={`${time}-${title}`}><time>{time}</time><i data-tone={index === 0 ? detail.tone : "muted"} /><span><strong>{title}</strong><small>{copy}</small></span></div>
          ))}
        </div>
      </section>
      <button className="primary-button profile-detail-done" onClick={onClose}>
        <Check size={18} /> 返回我的
      </button>
    </BottomSheet>
  );
}

function WidgetLayoutSheet({ tasks, visibleTaskCount, widgetSizes, onVisibleTaskCount, onSizeChange, onClose }) {
  const countOptions = tasks.length >= 2 ? [2, 3, 4].filter((count) => count <= tasks.length) : [tasks.length];
  const normalizedVisibleTaskCount = Math.min(visibleTaskCount, tasks.length);
  const visibleTasks = tasks.slice(0, normalizedVisibleTaskCount);

  return (
    <BottomSheet title="进程小组件" onClose={onClose} className="widget-layout-sheet">
      <section className="widget-layout-overview">
        <div className="widget-layout-overview-heading">
          <span><LayoutGrid size={21} /></span>
          <div><p>WIDGET BOARD</p><strong>{normalizedVisibleTaskCount} 个进程 · 自定义信息密度</strong></div>
        </div>
        <div className="widget-layout-preview" aria-label="当前小组件布局预览">
          {visibleTasks.map((task) => {
            const size = widgetSizes[task.id] || "2x2";
            const dimensions = widgetDimensions[size];
            return (
              <span
                data-tone={task.appTone}
                key={task.id}
                style={{ "--preview-columns": dimensions.columns, "--preview-rows": dimensions.rows }}
                title={`${task.title} · ${dimensions.label}`}
              ><b>{task.appCode}</b><small>{dimensions.label}</small></span>
            );
          })}
        </div>
      </section>

      <section className="widget-layout-section">
        <div className="widget-layout-section-heading"><div><p>显示进程</p><strong>当前工作区</strong></div><span>{normalizedVisibleTaskCount}/{tasks.length}</span></div>
        <div
          className="widget-count-segmented"
          role="group"
          aria-label="显示进程数量"
          style={{ "--widget-count-options": Math.max(1, countOptions.length) }}
        >
          {countOptions.map((count) => (
            <button
              className={normalizedVisibleTaskCount === count ? "active" : ""}
              data-testid={`widget-count-${count}`}
              aria-pressed={normalizedVisibleTaskCount === count}
              onClick={() => onVisibleTaskCount(count)}
              key={count}
            >{count} 个</button>
          ))}
        </div>
      </section>

      <section className="widget-layout-section">
        <div className="widget-layout-section-heading"><div><p>组件尺寸</p><strong>每个进程独立设置</strong></div></div>
        <div className="widget-layout-task-list">
          {visibleTasks.map((task) => {
            const activeSize = widgetSizes[task.id] || "2x2";
            return (
              <div className="widget-layout-task" data-tone={task.appTone} key={task.id}>
                <div className="widget-layout-task-heading">
                  <span className={`app-tile ${task.appTone}`}>{task.appCode}</span>
                  <span><strong>{task.title}</strong><small>{task.app} · {task.progress}%</small></span>
                </div>
                <div className="widget-size-options" role="group" aria-label={`${task.title} 的小组件尺寸`}>
                  {widgetSizeOptions.map((size) => (
                    <button
                      className={activeSize === size ? "active" : ""}
                      data-size={size}
                      data-testid={`widget-size-${task.id}-${size}`}
                      aria-label={`${task.title} ${widgetDimensions[size].label}`}
                      aria-pressed={activeSize === size}
                      onClick={() => onSizeChange(task.id, size)}
                      key={size}
                    >
                      <span className="widget-size-glyph" aria-hidden="true"><i /></span>
                      <small>{widgetDimensions[size].label}</small>
                    </button>
                  ))}
                </div>
              </div>
            );
          })}
        </div>
      </section>

      <button className="primary-button widget-layout-done" onClick={onClose}><Check size={18} /> 完成</button>
    </BottomSheet>
  );
}

function ManageTasksSheet({ tasks, onClose, onSave }) {
  const [items, setItems] = useState(
    tasks.map((task) => ({ ...task, reminder: task.reminder ?? task.status === "attention" })),
  );

  const moveTask = (index, direction) => {
    const target = index + direction;
    if (target < 0 || target >= items.length) return;
    setItems((current) => {
      const next = [...current];
      [next[index], next[target]] = [next[target], next[index]];
      return next;
    });
  };

  const updateTaskTitle = (index, title) => {
    setItems((current) =>
      current.map((task, itemIndex) => (itemIndex === index ? { ...task, title } : task)),
    );
  };

  const toggleTaskReminder = (index) => {
    setItems((current) =>
      current.map((task, itemIndex) =>
        itemIndex === index ? { ...task, reminder: !task.reminder } : task,
      ),
    );
  };

  return (
    <BottomSheet title="管理进程" onClose={onClose} className="manage-sheet">
      <p className="manage-intro">名称、顺序和关键提醒会同步到竖屏列表与横屏副屏。</p>
      <div className="manage-task-list">
        {items.map((task, index) => (
          <div className="manage-task-row" data-tone={task.appTone} key={task.id}>
            <span className={`app-tile ${task.appTone}`}>{task.appCode}</span>
            <span className="manage-task-copy">
              <input
                value={task.title}
                onChange={(event) => updateTaskTitle(index, event.target.value)}
                aria-label={`进程名称 ${index + 1}`}
              />
              <small>{task.app} · {task.statusLabel}</small>
            </span>
            <span className="manage-controls">
              <button
                className={`manage-reminder ${task.reminder ? "active" : ""}`}
                onClick={() => toggleTaskReminder(index)}
                aria-label={`${task.reminder ? "关闭" : "开启"} ${task.title} 的关键提醒`}
                aria-pressed={task.reminder}
                title="关键提醒"
              ><Bell size={15} /></button>
              <span className="manage-arrows">
              <button
                onClick={() => moveTask(index, -1)}
                disabled={index === 0}
                aria-label={`上移 ${task.title}`}
                title="上移"
              ><ChevronUp size={17} /></button>
              <button
                onClick={() => moveTask(index, 1)}
                disabled={index === items.length - 1}
                aria-label={`下移 ${task.title}`}
                title="下移"
              ><ChevronDown size={17} /></button>
              </span>
            </span>
          </div>
        ))}
      </div>
      <button
        className="primary-button"
        onClick={() => onSave(items.map((task) => ({ ...task, title: task.title.trim() || "未命名进程" })))}
      >
        <Check size={18} /> 保存调整
      </button>
    </BottomSheet>
  );
}

function InfoSheet({ type, onClose }) {
  const details = {
    account: {
      title: "账户设置",
      icon: UserRound,
      tone: "soft-blue",
      headline: "我的 Anchor",
      copy: "原型使用本机身份，不包含真实登录或账户服务。",
      facts: [["设备", "这台 iPhone"], ["工作区", "个人空间"], ["同步身份", "iCloud 本机账户"]],
    },
    icloud: {
      title: "iCloud 同步",
      icon: Cloud,
      tone: "soft-blue",
      headline: "上下文已保持同步",
      copy: "目标、进程状态和返航记录会在你的 Apple 设备间保持一致。",
      facts: [["当前状态", "已开启"], ["最近同步", "刚刚"], ["同步范围", "目标与任务状态"]],
    },
    privacy: {
      title: "数据与隐私",
      icon: ShieldCheck,
      tone: "soft-green",
      headline: "数据边界清晰可见",
      copy: "这个前端原型不上传任何信息；正式版本默认优先保留在用户自己的设备与 iCloud 中。",
      facts: [["原型数据", "仅浏览器内存"], ["外部上传", "无"], ["任务内容", "仅本机展示"]],
    },
    sources: {
      title: "已连接来源",
      icon: Layers3,
      tone: "soft-blue",
      headline: "4 个进程来源在线",
      copy: "当前状态由模拟数据驱动，用于还原未来 Mac 插件与 CLI 的同步体验。",
      facts: [["Claude", "在线"], ["Gemini", "在线"], ["Seedance", "在线"], ["Final Cut", "已连接"]],
    },
  };
  const detail = details[type] || details.account;
  const Icon = detail.icon;

  return (
    <BottomSheet title={detail.title} onClose={onClose}>
      <div className={`sheet-hero-icon ${detail.tone}`}><Icon size={25} /></div>
      <h2 className="sheet-headline">{detail.headline}</h2>
      <p className="info-copy">{detail.copy}</p>
      <div className="sheet-facts info-facts">
        {detail.facts.map(([label, value]) => (
          <div className="fact-row" key={label}><span>{label}</span><strong>{value}</strong></div>
        ))}
      </div>
      <button className="primary-button" onClick={onClose}><Check size={18} /> 完成</button>
    </BottomSheet>
  );
}

function FinishSheet({ tasks, onClose, onFinish }) {
  const progress = Math.round(tasks.reduce((sum, task) => sum + task.progress, 0) / tasks.length);
  return (
    <BottomSheet title="结束本次工作" onClose={onClose}>
      <div className="sheet-hero-icon soft-green"><FileCheck2 size={25} /></div>
      <h2 className="sheet-headline">保存这段工作脉络</h2>
      <div className="finish-metrics">
        <Metric value="42m" label="专注时间" />
        <Metric value={`${progress}%`} label="整体推进" />
        <Metric value="3" label="关键判断" />
      </div>
      <p className="finish-note">目标、任务状态、关键判断与返航记录会留在 Anchor 记忆中。</p>
      <button className="primary-button" onClick={onFinish}><FileCheck2 size={18} /> 结束并保存</button>
    </BottomSheet>
  );
}

function ReturnSheet({ goal, tasks, awayStarted, onClose, onComplete, onOpenTask }) {
  const minutes = awayStarted ? Math.max(1, Math.floor((Date.now() - awayStarted) / 60000)) : 18;
  const attentionTask = tasks.find((task) => task.status === "attention");
  const runningCount = tasks.filter((task) => task.status === "running").length;
  const impactDelta = 20;
  return (
    <div className="return-layer" role="dialog" aria-modal="true" aria-label="返航摘要">
      <StatusBar />
      <div className="return-nav">
        <button className="icon-button" onClick={onClose} aria-label="关闭返航摘要" title="关闭"><X size={19} /></button>
        <span>返航</span>
        <span className="return-sync"><i /> 已同步</span>
      </div>
      <main className="return-scroll">
        <header className="return-heading">
          <div className="return-visual" aria-hidden="true">
            <span className="return-icon"><AnchorIcon size={24} /></span>
            <i /><i /><i />
          </div>
          <div>
            <p className="eyebrow">返航 · 离开 {minutes} 分钟</p>
            <h1>欢迎回来，<br />工作已经被接住。</h1>
            <p className="return-heading-note">{goal.title}</p>
          </div>
        </header>

        <section className="return-impact" aria-labelledby="return-impact-heading">
          <div className="return-impact-topline">
            <p className="section-kicker">离开期间总影响</p>
            <span>+{impactDelta}%</span>
          </div>
          <h2 id="return-impact-heading">AI 们把工作向前推进了 {impactDelta}%</h2>
          <p>
            {attentionTask
              ? `${attentionTask.app} 已准备好 ${attentionTask.metric} 个${attentionTask.metricLabel}，正等你最终拍板。`
              : "所有进程都保持在同一个完成标准上，没有需要立即处理的异常。"}
          </p>
          <div className="return-impact-metrics">
            <span><strong>{returnChanges.length}</strong><small>项结果更新</small></span>
            <span><strong>{runningCount}</strong><small>个持续运行</small></span>
            <span><strong>{attentionTask ? 1 : 0}</strong><small>个等待判断</small></span>
          </div>
        </section>

        <details className="return-change-details">
          <summary>
            <span><History size={16} /> 查看 {returnChanges.length} 条具体变化</span>
            <ChevronDown size={16} />
          </summary>
          <div className="change-timeline">
            {returnChanges.map((item) => (
              <div className="change-row" key={item.time}>
                <time>{item.time}</time><i className={item.tone} /><span><strong>{item.title}</strong><small>{item.detail}</small></span>
              </div>
            ))}
          </div>
        </details>

        {attentionTask && (
          <button className="return-decision" onClick={() => onOpenTask(attentionTask.id)} data-testid="return-primary-decision">
            <span className="decision-icon"><CircleAlert size={19} /></span>
            <span>
              <small>你的下一步</small>
              <strong>{attentionTask.title}</strong>
              <p>{attentionTask.detail}</p>
              <em>完成选择后，Anchor 会自动接回工作流</em>
            </span>
            <ChevronRight size={18} />
          </button>
        )}
      </main>
      <div className="return-footer">
        <button
          className="primary-button"
          onClick={() => attentionTask ? onOpenTask(attentionTask.id) : onComplete()}
          data-testid="return-complete"
        >
          <Play size={17} fill="currentColor" />
          继续工作
        </button>
      </div>
      <HomeIndicator />
    </div>
  );
}

function HandoffOverlay({ phase, tasks }) {
  const secured = phase === "secured";

  return (
    <div className={`handoff-overlay is-${phase}`} role="status" aria-live="polite">
      <div className="handoff-stage" aria-hidden="true">
        {tasks.slice(0, 4).map((task) => (
          <span className="handoff-mini-card" data-tone={task.appTone} key={task.id}>
            <i>{task.appCode}</i><b /><em />
          </span>
        ))}
        <span className="handoff-anchor-core">
          {secured ? <Check size={28} strokeWidth={2.4} /> : <AnchorIcon size={29} strokeWidth={2.2} />}
        </span>
        <i className="handoff-ring ring-one" />
        <i className="handoff-ring ring-two" />
      </div>
      <div className="handoff-copy">
        <strong>{secured ? "已接管，放心离开" : "正在收好工作脉络"}</strong>
        <span>{secured ? "目标、进程与待判断节点会继续保持" : `Anchor 正在把 ${tasks.length} 个进程收回同一个锚点`}</span>
      </div>
    </div>
  );
}

function Toast({ message }) {
  return (
    <div className="toast" role="status">
      <AnchorCompanion mood="happy" />
      <span>{message}</span>
      <i className="toast-splash splash-one" aria-hidden="true" />
      <i className="toast-splash splash-two" aria-hidden="true" />
    </div>
  );
}

function AnchorCompanion({ mood = "happy" }) {
  return (
    <span className={`anchor-companion is-${mood}`} aria-hidden="true">
      <AnchorIcon size={18} strokeWidth={2.35} />
      <i className="anchor-companion-face" />
    </span>
  );
}

function HomeIndicator() {
  return <div className="home-indicator" aria-hidden="true"><i /></div>;
}

export default App;
