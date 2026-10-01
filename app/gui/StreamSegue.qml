import QtQuick 2.0
import QtQuick.Controls
import QtQuick.Window 2.2

import SdlGamepadKeyNavigation 1.0
import Session 1.0
import SystemProperties 1.0
import StreamingPreferences 1.0

import "theme"
import "Brand.js" as Brand

Item {
    property Session session
    property string appName

    // PrimSec: обложки и зум-фоны вырезаны - на загрузке ровный тёмный
    // фон и ротация весёлых фраз (как на экране установки PrimSec).
    property string boxArtUrl: ""

    // 自带背景，main.qml 的全局壁纸层不用再垫一层
    readonly property bool usesOwnBackground: true

    property var memPhrases: [
        qsTr("Прогреваем пиксели..."),
        qsTr("Договариваемся с видеокартой..."),
        qsTr("Сжимаем кадры покрепче..."),
        qsTr("Переливаем картинку по проводу..."),
        qsTr("Будим твою мышку..."),
        qsTr("Полируем курсор до блеска..."),
        qsTr("Запускаем хомяков в колесо..."),
        qsTr("Настраиваем телепорт...")
    ]
    property int memIdx: 0
    property string stageText: memPhrases[0]
    property bool isResume : false
    property bool quitAfter : false

    Timer {
        id: memTimer
        interval: 1500
        repeat: true
        running: contentRoot.opacity > 0 && stageLabel.visible
        onTriggered: {
            memIdx = (memIdx + 1) % memPhrases.length
            stageText = memPhrases[memIdx]
        }
    }

    // 退出组合键提示随设置走：玩家改了组合键，提示不能还教默认那套。
    // 按键名按当前手柄风格显示（PS 显示 Options/Share/✕，Switch 显示 +/−），
    // swapFaceButtons 时补偿到实际要按的物理键
    function quitComboHintText()
    {
        var nav = SdlGamepadKeyNavigation
        var swap = StreamingPreferences.swapFaceButtons
        var lb = nav.leftShoulderName()
        var rb = nav.rightShoulderName()
        var face = function(i) { return nav.faceButtonGlyph(swap ? (i ^ 1) : i) }
        var shoulders = lb + "+" + rb
        switch (StreamingPreferences.gamepadQuitCombo) {
        case StreamingPreferences.GQC_SELECT_L1_R1_Y:
            return nav.selectButtonName() + "+" + shoulders + "+" + face(3)
        case StreamingPreferences.GQC_START_L1_R1_A:
            return nav.startButtonName() + "+" + shoulders + "+" + face(0)
        case StreamingPreferences.GQC_START_L1_R1_B:
            return nav.startButtonName() + "+" + shoulders + "+" + face(1)
        case StreamingPreferences.GQC_L1_R1_X_Y:
            return shoulders + "+" + face(2) + "+" + face(3)
        case StreamingPreferences.GQC_L1_R1_A_B:
            return shoulders + "+" + face(0) + "+" + face(1)
        default:
            return nav.startButtonName() + "+" + nav.selectButtonName() + "+" + shoulders
        }
    }

    function stageStarting(stage)
    {
        // Технические имена этапов на экран не выводим - крутится
        // ротация memPhrases, этап остаётся в логе.
        console.log("stage: " + stage)
    }

    function stageFailed(stage, errorCode, failingPorts)
    {
        // Display the error dialog after Session::exec() returns
        streamSegueErrorDialog.text = qsTr("Не удалось подключиться (%1, ошибка %2)").arg(stage).arg(errorCode)

        if (failingPorts) {
            streamSegueErrorDialog.text += "\n\n" + qsTr("Проверь, не блокирует ли сеть порты: %1").arg(failingPorts)
        }
    }

    function hideForStreaming()
    {
        // Hide the UI contents so the user doesn't
        // see them briefly when we pop off the StackView
        stageSpinner.visible = false
        stageLabel.visible = false
        hintText.visible = false

        // 窗口本身不在这里藏，由 Session::exec() 在串流窗口进入全屏之后隐藏。
        // 提前藏的话，macOS 切进新 Space 的整个动画期间旧 Space 露出来的是桌面，
        // 而不是这层已经全黑的幕。
    }

    function connectionStarted()
    {
        // 淡出到全黑。Session::exec() 会等这条动画跑完再创建串流窗口，
        // 所以交接是在一块纯黑上完成的，中间不会闪。
        exitAnimation.start()
    }

    function displayLaunchError(text)
    {
        // Display the error dialog after Session::exec() returns
        streamSegueErrorDialog.text = text
        console.error(text)
    }

    function quitStarting()
    {
        // Avoid the push transition animation
        var component = Qt.createComponent("QuitSegue.qml")
        stackView.replace(stackView.currentItem, component.createObject(stackView, {"appName": appName}), StackView.Immediate)

        // Show the Qt window again to show quit segue
        window.visible = true
    }

    function sessionFinished(portTestResult)
    {
        if (portTestResult !== 0 && portTestResult !== -1 && streamSegueErrorDialog.text) {
            streamSegueErrorDialog.text += "\n\n" + Brand.text(qsTr("This PC's Internet connection is blocking Moonlight. Streaming over the Internet may not work while connected to this network."))
        }

        // Re-enable GUI gamepad usage now
        SdlGamepadKeyNavigation.enable()

        // Pop the StreamSegue off the stack if this is a GUI-based app launch
        if (!quitAfter) {
            stackView.pop()
        }

        if (quitAfter && !streamSegueErrorDialog.text) {
            // If this was a CLI launch without errors, exit now
            Qt.quit()
        }
        else {
            // Show the Qt window again after streaming
            window.visible = true

            // Display any launch errors. We do this after
            // the Qt UI is visible again to prevent losing
            // focus on the dialog which would impact gamepad
            // users.
            if (streamSegueErrorDialog.text) {
                streamSegueErrorDialog.quitAfter = quitAfter
                streamSegueErrorDialog.open()
            }
        }
    }

    function sessionReadyForDeletion()
    {
        // Garbage collect the Session object since it's pretty heavyweight
        // and keeps other libraries (like SDL_TTF) around until it is deleted.
        session = null
        gc()
    }

    StackView.onDeactivating: {
        // Show the toolbar again when popped off the stack
        toolBar.shown = true

        // Re-enable GUI gamepad usage now
        SdlGamepadKeyNavigation.enable()
    }

    StackView.onActivated: {
        // Hide the toolbar before we start loading
        toolBar.shown = false

        // Hook up our signals
        session.stageStarting.connect(stageStarting)
        session.stageFailed.connect(stageFailed)
        session.connectionStarted.connect(connectionStarted)
        session.displayLaunchError.connect(displayLaunchError)
        session.quitStarting.connect(quitStarting)
        session.sessionFinished.connect(sessionFinished)
        session.readyForDeletion.connect(sessionReadyForDeletion)

        // Ensure the SystemProperties async thread is finished,
        // since it may currently be using the SDL video subsystem
        SystemProperties.waitForAsyncLoad()

        enterAnimation.start()

        // Kick off the stream
        streamLoader.active = true
    }

    // PrimSec: ровный тёмный фон вместо обложек и зум-анимаций.
    // Свой арт добавим позже - слой уже наш.
    Rectangle {
        anchors.fill: parent
        color: Theme.ink
        z: -1
    }

    // 进入串流时盖上来的幕，替代原来「一帧之内直接隐藏窗口」的硬切。
    //
    // 这一层刻意用纯黑而不是 Theme.ink：接手它的是 SDL 串流窗口，而 SDL 窗口在拿到
    // 第一帧之前就是纯黑的（实测 macOS 上是 0,0,0）。两边同色，交接那一刻才没有色阶跳变。
    Rectangle {
        id: exitVeil
        anchors.fill: parent
        color: "black"
        opacity: 0
        visible: opacity > 0
        z: 10
    }

    ParallelAnimation {
        id: enterAnimation
        NumberAnimation {
            target: contentRoot; property: "opacity"
            from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: contentShift; property: "y"
            from: 14; to: 0; duration: 480; easing.type: Easing.OutCubic
        }
    }

    // 进入串流：内容淡出、背景轻微推近、黑幕盖上来，三件事一起做，
    // 读起来像是「被带进游戏」而不是窗口突然不见了。
    ParallelAnimation {
        id: exitAnimation

        NumberAnimation {
            target: contentRoot; property: "opacity"
            to: 0; duration: 260; easing.type: Easing.InCubic
        }
        SequentialAnimation {
            NumberAnimation {
                target: exitVeil; property: "opacity"
                to: 1; duration: 340; easing.type: Easing.InOutQuad
            }
            ScriptAction {
                script: hideForStreaming()
            }
        }
    }

    Timer {
        id: startSessionTimer
        onTriggered: {
            // Garbage collect QML stuff before we start streaming,
            // since we'll probably be streaming for a while and we
            // won't be able to GC during the stream.
            gc()

            // Run the streaming session to completion
            session.start()
        }
    }

    Loader {
        id: streamLoader
        active: false
        asynchronous: true

        onLoaded: {
            // Set the hint text. We do this here rather than
            // in the hintText control itself to synchronize
            // with Session.exec() which requires no concurrent
            // gamepad usage.
            hintText.text = qsTr("Подсказка: %1 — отключиться").arg(SdlGamepadKeyNavigation.getConnectedGamepads() > 0 &&
                                                  SdlGamepadKeyNavigation.gamepadQuitComboEnabled() ?
                                                  quitComboHintText() : qsTr("Ctrl+Alt+Shift+Q"))

            // Stop GUI gamepad usage now
            SdlGamepadKeyNavigation.disable()

            // Initialize the session and probe for host/client capabilities
            if (!session.initialize(window)) {
                sessionFinished(0);
                sessionReadyForDeletion();
                return;
            }

            // This spinner is shown only after session.initialize() has completed
            // to prevent active animations from running during decoder probing,
            // which causes re-entrant event loop livelocks with libdecor-gtk.
            stageSpinner.visible = true

            // Don't wait unless we have toasts to display
            startSessionTimer.interval = 0

            // Display the toasts together in a vertical centered arrangement
            var yOffset = 0
            for (var i = 0; i < session.launchWarnings.length; i++) {
                var text = session.launchWarnings[i]
                console.warn(text)

                // Show the tooltip for 3 seconds
                var toast = Qt.createQmlObject('import QtQuick.Controls 2.2; ToolTip {}', parent, '')
                toast.timeout = 3000
                toast.text = text
                toast.y += yOffset
                toast.visible = true

                // Offset the next toast below the previous one
                yOffset = toast.y + toast.padding + toast.height

                // Allow an extra 500 ms for the tooltip's fade-out animation to finish
                startSessionTimer.interval = toast.timeout + 500;
            }

            // Start the timer to wait for toasts (or start the session immediately)
            startSessionTimer.start()
        }

        sourceComponent: Item {}
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        opacity: 0

        // 淡入的同时轻微上浮
        transform: Translate {
            id: contentShift
            y: 14
        }

        // 阶段文字 + 斜条纹读条。转圈的 BusyIndicator 换成 HardProgress。
        // stageSpinner 这个 id 和 visible 语义保持不变：spinnerTimer 和
        // hideForStreaming() 都在用。
        Column {
            anchors.centerIn: parent
            width: Math.min(parent.width - Theme.spaceXl * 2, 620)
            spacing: Theme.spaceLg

            Text {
                id: stageLabel

                width: parent.width
                text: stageText
                color: Theme.text
                font.family: Theme.fontSans
                font.pointSize: 24
                font.weight: Font.ExtraBold
                font.letterSpacing: Theme.trackingTight(24)
                // PrimSec: по центру - фразы ротации почти одной длины,
                // «прыжков» нет, а запрос был именно про центр экрана.
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            HardProgress {
                id: stageSpinner

                width: parent.width
                visible: false
            }
        }

        Text {
            id: hintText
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 50
            anchors.horizontalCenter: parent.horizontalCenter
            color: Theme.textDim
            font.family: Theme.fontMono
            font.pointSize: Theme.fontBody
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            wrapMode: Text.Wrap
        }
    }
}
