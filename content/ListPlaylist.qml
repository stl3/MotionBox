//=================================================================================================
/*
    Copyright (C) 2015-2016 MotionBox authors united with omega. <http://omega.gg/about>

    Author: Benjamin Arnaud. <http://bunjee.me> <bunjee@omega.gg>

    This file is part of MotionBox.

    - GNU General Public License Usage:
    This file may be used under the terms of the GNU General Public License version 3 as published
    by the Free Software Foundation and appearing in the LICENSE.md file included in the packaging
    of this file. Please review the following information to ensure the GNU General Public License
    requirements will be met: https://www.gnu.org/licenses/gpl.html.
*/
//=================================================================================================

import QtQuick       1.1
import Sky           1.0
import SkyComponents 1.0

List
{
    id: list

    //---------------------------------------------------------------------------------------------
    // Properties
    //---------------------------------------------------------------------------------------------

    /* read */ property bool hasPlaylist: false

    property PlaylistNet playlist: null

    /* read */ property bool isSelecting: false

    /* read */ property variant itemHovered: null

    /* read */ property int indexHover: (itemHovered) ? itemHovered.getIndex() : -1

    /* read */ property int indexPreview   : -1
    /* read */ property int indexContextual: -1
    /* read */ property int indexPlayer    : -1

    /* read */ property int indexActive: (indexContextual != -1) ? indexContextual
                                                                 : indexHover

    property bool enableLoad      : true
    property bool enablePreview   : true
    property bool enableContextual: true
    property bool enableAdd       : true
    property bool enableLink      : false
    property bool enableDrag      : true
    property bool enableDragMove  : false

    property variant itemLeft  : null
    property variant itemRight : null
    property variant itemTop   : null
    property variant itemBottom: null

    //---------------------------------------------------------------------------------------------
    // Private

    property PlaylistNet pPlaylist: null

    property bool pSelect: true
    property bool pScroll: true

    property variant pIndexes: null

    property int pDragX: -1
    property int pDragY: -1

    //---------------------------------------------------------------------------------------------
    // Aliases
    //---------------------------------------------------------------------------------------------

    property alias linkIcon          : buttonLink.icon
    property alias linkIconSourceSize: buttonLink.iconSourceSize

    //---------------------------------------------------------------------------------------------

    property alias overlay: overlay

    property alias checkBox        : checkBox
    property alias buttonContextual: buttonContextual
    property alias buttonLink      : buttonLink

    property alias itemWatcher: itemWatcher

    //---------------------------------------------------------------------------------------------
    // Signals
    //---------------------------------------------------------------------------------------------

    signal link(int index)

    //---------------------------------------------------------------------------------------------
    // Settings
    //---------------------------------------------------------------------------------------------

    model: ModelPlaylistNet { id: model }

    delegate: ComponentTrack {}

    //---------------------------------------------------------------------------------------------
    // Events
    //---------------------------------------------------------------------------------------------

    onPlaylistChanged:
    {
        if (playlist)
        {
            if (enableLoad) playlist.loadQuery();

            hasPlaylist = true;

            pApplyPlaylist();

            pUpdateSelected();

            pUpdatePlayerOverlay();

            pLoadTracks();

            pRestoreScroll();
        }
        else
        {
            hasPlaylist = false;

            pApplyPlaylist();
        }

        pUpdateCurrentY();
    }

    //---------------------------------------------------------------------------------------------
    // Keys
    //---------------------------------------------------------------------------------------------

    Keys.onPressed:
    {
        if (playlist == null) return;

        var index;

        if (event.key == Qt.Key_Up && (event.modifiers == Qt.NoModifier
                                       ||
                                       event.modifiers == Qt.ShiftModifier))
        {
            event.accepted = true;

            selectPreviousTrack();

            areaContextual.hidePanels();
        }
        else if (event.key == Qt.Key_Down && (event.modifiers == Qt.NoModifier
                                              ||
                                              event.modifiers == Qt.ShiftModifier))
        {
            event.accepted = true;

            selectNextTrack();

            areaContextual.hidePanels();
        }
        else if (event.key == Qt.Key_Left && event.modifiers == Qt.NoModifier)
        {
            event.accepted = true;

            if (itemLeft) itemLeft.focus();
        }
        else if (event.key == Qt.Key_Right && event.modifiers == Qt.NoModifier)
        {
            event.accepted = true;

            if (itemRight) itemRight.focus();
        }
        else if ((event.key == Qt.Key_Return || event.key == Qt.Key_Enter))
        {
            event.accepted = true;

            index = playlist.lastSelected;

            pSetCurrentTrack(index);

            pPlay();
        }
        else if (event.key == Qt.Key_Escape)
        {
            event.accepted = true;

            window.clearFocus();
        }
        else if (event.key == Qt.Key_Menu && enableContextual)
        {
            event.accepted = true;

            index = playlist.lastSelected;

            scrollToItem(index);

            panelContextual.loadPageTrack(list, index);

            pShowPanel(panelContextual, index, -1, -1, false);
        }
        else if (event.key == Qt.Key_Plus && enableAdd)
        {
            event.accepted = true;

            index = playlist.lastSelected;

            scrollToItem(index);

            panelAdd.setSource(0, playlist, -1);

            pShowPanel(panelAdd, index, -1, -1, false);
        }
        else if (event.key == Qt.Key_Delete)
        {
            event.accepted = true;

            if (list != gui.listPlaylist) return;

            index = playlist.lastSelected;

            if (index == -1) return;

            if (playlist.selectedCount == 1)
            {
                var item = itemAt(index);

                if (item)
                {
                    removeTrack(index, true);
                }
                else scrollToItem(index);
            }
            else
            {
                scrollToItem(index);

                showPanel(index);

                areaContextual.currentPage.currentId = 2;
            }
        }
        else if (event.key == Qt.Key_A && event.modifiers == Qt.ControlModifier)
        {
            event.accepted = true;

            playlist.selectAll();
        }
    }

    //---------------------------------------------------------------------------------------------
    // Connections
    //---------------------------------------------------------------------------------------------

    Connections
    {
        target: sk

        onAboutToQuit: saveScroll()
    }

    Connections
    {
        target: gui

        onScaleBefore: saveScroll    ()
        onScaleAfter : pRestoreScroll()
    }

    Connections
    {
        target: (hasPlaylist) ? playlist : null

        onLoaded        : pLoadTracks()
        onQueryCompleted: pLoadTracks()

        onSelectedTracksChanged:
        {
            pUpdateCurrentY();

            pUpdateCheckBox(indexHover);

            if (playlist.selectedCount != 1) return;

            setPlaylistFocus(playlist);

            var index = playlist.lastSelected;

            if (player.isPlaying == false || highlightedTab)
            {
                pSetCurrentTrack(index);
            }

            if (index != -1 && pScroll)
            {
                scrollToItem(index);
            }
        }

        onTracksInserted:
        {
            if      (indexPreview    >= index) indexPreview    += count;
            if      (indexContextual >= index) indexContextual += count;
            else if (indexPlayer     >= index) indexPlayer     += count;
        }

        onTracksRemoved:
        {
            var countPreview    = 0;
            var countContextual = 0;
            var countPlayer     = 0;

            for (var i = 0; i < indexes.length; i++)
            {
                var index = indexes[i];

                if      (indexPreview    > index) countPreview++;
                if      (indexContextual > index) countContextual++;
                else if (indexPlayer     > index) countPlayer++;
            }

            indexPreview    -= countPreview;
            indexContextual -= countContextual;
            indexPlayer     -= countPlayer;
        }

        onTracksMoved:
        {
            indexPreview    = -1;
            indexContextual = -1;
            indexPlayer     = -1;
        }

        onTracksCleared:
        {
            timer.stop();

            pIndexes = null;

            pClearPreview();

            itemHovered = null;

            indexPreview    = -1;
            indexContextual = -1;
            indexPlayer     = -1;

            pUpdateCurrentY();
        }
    }

    Connections
    {
        target: tabs

        onCurrentTabChanged: pUpdateSelected()
    }

    Connections
    {
        target: currentTab

        onCurrentBookmarkChanged:
        {
            if (playlist && pSelect && (player.isPlaying == false || highlightedTab))
            {
                if (currentTab.playlist == playlist)
                {
                     playlist.selectSingleTrack(playlist.currentIndex);
                }
                else playlist.unselectTracks();
            }
        }
    }

    Connections
    {
        target: player

        onCurrentTrackUpdated: pUpdatePlayerOverlay()
        onHasStartedChanged  : pUpdatePlayerOverlay()
    }

    //---------------------------------------------------------------------------------------------
    // Functions
    //---------------------------------------------------------------------------------------------

    function focus()
    {
        if (activeFocus || count == 0) return;

        forceActiveFocus();

        if (playlist.selectedCount == 0)
        {
            var index = playlist.currentIndex;

            if (index == -1) index = 0;

            playlist.selectSingleTrack(index);

            scrollToItem(index);
        }
        else scrollToItem(playlist.lastSelected);
    }

    function focusList()
    {
        forceActiveFocus();
    }

    //---------------------------------------------------------------------------------------------

    function selectTrack(index)
    {
        if (count) pSelectTrack(index);
    }

    function selectSingleTrack(index)
    {
        if (count) pSelectSingleTrack(index);
    }

    //---------------------------------------------------------------------------------------------

    function unselectTrack(index)
    {
        if (count) playlist.unselectTrack(index);
    }

    //---------------------------------------------------------------------------------------------

    function selectPreviousTrack()
    {
        if (playlist == null) return;

        var last = playlist.lastSelected;

        var index;

        if (last == -1 || last == 0)
        {
            if (itemTop) itemTop.focus();

            return;
        }
        else index = last - 1;

        if (window.keyShiftPressed)
        {
            if (playlist.selectedCount > 1)
            {
                if (playlist.selectedAligned)
                {
                    var first = playlist.firstSelected;

                    if (first > index)
                    {
                         playlist.selectTrack(index);
                    }
                    else playlist.unselectTrack(last);

                    scrollToItem(index);
                }
                else
                {
                    playlist.selectSingleTrack(last);

                    if (last > 0)
                    {
                        last--;

                        playlist.selectTrack(last);

                        scrollToItem(last);
                    }
                }
            }
            else
            {
                playlist.selectTrack(index);

                scrollToItem(index);
            }
        }
        else playlist.selectSingleTrack(index);
    }

    function selectNextTrack()
    {
        if (playlist == null) return;

        var last = playlist.lastSelected;

        var index;

        if (last == -1 || last == (count - 1))
        {
            if (itemBottom) itemBottom.focus();

            return;
        }
        else index = last + 1;

        if (window.keyShiftPressed)
        {
            if (playlist.selectedCount > 1)
            {
                if (playlist.selectedAligned)
                {
                    var first = playlist.firstSelected;

                    if (first < index)
                    {
                         playlist.selectTrack(index);
                    }
                    else playlist.unselectTrack(last);

                    scrollToItem(index);
                }
                else
                {
                    playlist.selectSingleTrack(last);

                    if (last != -1 && last != (count -1))
                    {
                        last++;

                        playlist.selectTrack(last);

                        scrollToItem(last);
                    }
                }
            }
            else
            {
                playlist.selectTrack(index);

                scrollToItem(index);
            }
        }
        else playlist.selectSingleTrack(index);
    }

    //---------------------------------------------------------------------------------------------

    function playAt(index)
    {
        if (index < 0 || index >= count) return;

        gui.playTrack(playlist, index, false);
    }

    function playFirstTrack()
    {
        if (count == 0) return;

        if (indexPlayer == -1)
        {
            var index;

            if (playlist.currentId == -1)
            {
                 index = 0;
            }
            else index = playlist.currentIndex

            gui.playTrack(playlist, index, true);
        }
        else player.play();

        playlist.selectCurrentTrack();
    }

    //---------------------------------------------------------------------------------------------

    function setItemHovered(item)
    {
        if (itemHovered == item) return;

        itemHovered = item;

        if (indexContextual == -1)
        {
            pUpdateCheckBox(indexHover);
        }
    }

    function clearItemHovered()
    {
        itemHovered = null;
    }

    //---------------------------------------------------------------------------------------------

    function showPanelAt(index, x, y, isCursorChild)
    {
        if (enableContextual == false || index == -1) return;

        panelContextual.loadPageTrack(list, index);

        pShowPanel(panelContextual, index, x, y, isCursorChild);
    }

    function showPanel(index)
    {
        showPanelAt(index, -1, -1, false);
    }

    //---------------------------------------------------------------------------------------------

    function showAddAt(index, x, y, isCursorChild)
    {
        if (enableAdd == false || index == -1) return;

        panelAdd.setSource(0, playlist, -1);

        pShowPanel(panelAdd, index, x, y, isCursorChild);
    }

    function showAdd(index)
    {
        showAddAt(index, -1, -1, false);
    }

    //---------------------------------------------------------------------------------------------

    function insertSource(index, url, animate)
    {
        if (playlist == null || playlist.isFull)
        {
            return false;
        }

        if (index == -1)
        {
            if (playlist.isFeed) index = 0;
            else                 index = count;
        }

        var size = playlist.insertSource(index, url);

        playlist.loadTracks(index, 5);

        if (animate)
        {
            var array = new Array;

            while (size)
            {
                array.push(index);

                index++;

                size--;
            }

            animateAdd(array);
        }

        return true;
    }

    //---------------------------------------------------------------------------------------------

    function copyTracksFrom(source, indexes, to, animate)
    {
        var length = indexes.length;

        if (playlist == null || playlist.checkFull(length))
        {
            return false;
        }

        if (to == -1)
        {
            if (playlist.isFeed) to = 0;
            else                 to = count;
        }

        source.copyTracksTo(indexes, playlist, to);

        if (animate)
        {
            var array = new Array;

            for (var i = 0; i < length; i++)
            {
                array.push(to);

                to++;
            }

            animateAdd(array);
        }

        return true;
    }

    function copyTrackFrom(source, from, to, animate)
    {
        if (from == -1)
        {
            return copyTracksFrom(source, source.selectedTracks, to, animate);
        }
        else if (playlist == null || playlist.isFull)
        {
            return false;
        }

        if (to == -1)
        {
            if (playlist.isFeed) to = 0;
            else                 to = count;
        }

        source.copyTrackTo(from, playlist, to);

        if (animate)
        {
            var array = new Array;

            array.push(to);

            animateAdd(array);
        }

        return true;
    }

    function copySelectedFrom(source, to, animate)
    {
        return copyTracksFrom(source, source.selectedTracks, to, animate);
    }

    //---------------------------------------------------------------------------------------------

    function animateAdd(indexes)
    {
        var animate = false;

        var count = Math.min(indexes.length, 20);

        for (var i = 0; i < count; i++)
        {
            var item = itemAt(indexes[i]);

            if (item)
            {
                item.animateAdd();

                animate = true;
            }
        }

        if (animate) timer.start();
    }

    //---------------------------------------------------------------------------------------------

    function removeTrack(index, animate)
    {
        if (index < 0 || index >= count) return;

        var array = new Array;

        array.push(index);

        pRemove(array, animate);
    }

    function removeSelected(animate)
    {
        if (playlist == null) return;

        pRemove(playlist.selectedTracks, animate);
    }

    //---------------------------------------------------------------------------------------------

    function openInTab(index)
    {
        if (index < 0 || index >= count) return;

        if (currentTab.playlist == playlist)
        {
            var indexTab = tabs.indexOf(currentTab) + 1;

            if (itemTabs.openTabAt(indexTab) == false) return;
        }
        else if (itemTabs.openTab() == false) return;

        wall.asynchronous = Image.AsynchronousOff;

        playlist.selectSingleTrack(index);

        wall.asynchronous = Image.AsynchronousOn;
    }

    //---------------------------------------------------------------------------------------------

    function scrollToCurrentItem()
    {
        if (playlist) scrollToItem(playlist.currentIndex);
    }

    //---------------------------------------------------------------------------------------------

    function currentItemY()
    {
        if (playlist) return itemY(playlist.currentIndex);
        else          return -1;
    }

    function selectedItemY()
    {
        if (playlist == null) return -1;

        var index = playlist.lastSelected;

        if (index == -1) return -1;
        else             return itemY(index);
    }

    //---------------------------------------------------------------------------------------------

    function saveScroll()
    {
        if (playlist) pSaveScroll(playlist);
    }

    //---------------------------------------------------------------------------------------------
    // Events

    function onContextualClear()
    {
        if (indexContextual != indexHover)
        {
            areaContextual.clearLastParent();
        }

        indexContextual = -1;
    }

    //---------------------------------------------------------------------------------------------
    // Private

    function pApplyPlaylist()
    {
        if (pPlaylist)
        {
            pProcessRemove(pPlaylist);

            pPlaylist.unselectTracks();

            pPlaylist.abortTracks();
            pPlaylist.abortQuery ();

            pSaveScroll(pPlaylist);
        }

        pClearPreview();

        itemHovered = null;

        indexPreview    = -1;
        indexContextual = -1;
        indexPlayer     = -1;

        pPlaylist = playlist;

        model.playlist = playlist;
    }

    //---------------------------------------------------------------------------------------------

    function pSetCurrentTrack(index)
    {
        gui.setCurrentTrack(playlist, index);
    }

    function pUpdateCurrentTrack(index)
    {
        if (player.isPlaying == false || highlightedTab)
        {
            pSelect = false;

            playlist.currentIndex = index;

            pSelect = true;
        }
    }

    //---------------------------------------------------------------------------------------------

    function pSelectTrack(index)
    {
        if (playlist.indexSelected(index))
        {
            if (window.keyControlPressed)
            {
                pScroll = false;

                if (playlist.currentIndex == index)
                {
                    playlist.unselectTrack(index);

                    pSelect = false;

                    playlist.currentIndex = playlist.lastSelected;

                    pSelect = true;
                }
                else playlist.unselectTrack(index);

                pScroll = true;

                scrollToItem(index);
            }
            else if (window.keyShiftPressed == false)
            {
                playlist.selectSingleTrack(index);
            }
        }
        else
        {
            if (window.keyShiftPressed)
            {
                if (playlist.selectedAligned == false)
                {
                    var last = playlist.lastSelected;

                    playlist.selectSingleTrack(last);
                }

                var closest = playlist.closestSelected(index);

                if (closest != -1)
                {
                    playlist.selectTracks(closest, index);

                    scrollToItem(index);

                    pUpdateCurrentTrack(index);
                }
                else playlist.selectSingleTrack(index);
            }
            else if (window.keyControlPressed)
            {
                playlist.selectTrack(index);

                scrollToItem(index);

                pUpdateCurrentTrack(index);
            }
            else playlist.selectSingleTrack(index);
        }
    }

    function pSelectSingleTrack(index)
    {
        playlist.selectSingleTrack(index);
    }

    //---------------------------------------------------------------------------------------------

    function pLoadTracks()
    {
        var index;

        if (playlist.currentIndex == -1)
        {
             index = 0;
        }
        else index = playlist.currentIndex;

        for (var i = index; i < count; i++)
        {
            if (playlist.trackTitle(i) == "")
            {
                playlist.loadTracks(index, 5);

                return;
            }
        }
    }

    //---------------------------------------------------------------------------------------------

    function pPlay()
    {
        if (highlightedTab) tabs.highlightedTab = null;

        player.replay();

        window.clearFocus();
    }

    //---------------------------------------------------------------------------------------------

    function pShowPanel(panel, index, x, y, isCursorChild)
    {
        indexContextual = index;

        if (areaContextual.showPanelAt(panel, itemWatcher, x, y, isCursorChild))
        {
            areaContextual.parentContextual = list;

            pUpdateCheckBox(index);
        }
        else indexContextual = -1;
    }

    //---------------------------------------------------------------------------------------------

    function pDragInit(x, y)
    {
        if (enableDrag == false) return;

        pDragX = x;
        pDragY = y;
    }

    function pDragCheck(x, y)
    {
        if (window.testDrag(Qt.point(pDragX, pDragY), Qt.point(x, y), 8) == false)
        {
            return;
        }

        isSelecting = false;

        playlist.addDeleteLock();

        pDragX = -1;
        pDragY = -1;

        gui.drag     = 0;
        gui.dragList = list;
        gui.dragItem = playlist;
        gui.dragData = playlist.selectedTracks;

        if (scrollArea && list != gui.listPlaylist)
        {
            areaDrag.setItem(scrollArea);
        }

        var source;

        var count = playlist.selectedCount;

        if (count == 1)
        {
            var index = playlist.lastSelected;

            var data = playlist.trackData(index);

            source = data.source;

            toolTip.showIcon(data.title, st.icon42x32_track, data.cover, 42, 32);
        }
        else
        {
            source = playlist.selectedSources;

            toolTip.show(count + " " + qsTr("Tracks"), st.icon32x32_track, 32, 32);
        }

        if (enableDragMove)
        {
             window.startDrag(source, Qt.MoveAction | Qt.CopyAction);
        }
        else window.startDrag(source, Qt.CopyAction);
    }

    //---------------------------------------------------------------------------------------------

    function pUpdateSelected()
    {
        if (playlist == null) return;

        if (currentTab.playlist == playlist)
        {
            pScroll = false;

            playlist.selectSingleTrack(playlist.currentIndex);

            pScroll = true;
        }
        else playlist.unselectTracks();
    }

    //---------------------------------------------------------------------------------------------

    function pUpdateCurrentY()
    {
        if (scrollArea) scrollArea.updateCurrentY();
    }

    function pUpdateVisible()
    {
        if (scrollArea) scrollArea.updateVisible();
    }

    //---------------------------------------------------------------------------------------------

    function pUpdatePlayerOverlay()
    {
        if (player.hasStarted && playlist && player.playlist == playlist)
        {
             indexPlayer = player.trackIndex;
        }
        else indexPlayer = -1;
    }

    //---------------------------------------------------------------------------------------------

    function pUpdateCheckBox(index)
    {
        if (playlist && playlist.indexSelected(index))
        {
             checkBox.checked = true;
        }
        else checkBox.checked = false;
    }

    //---------------------------------------------------------------------------------------------

    function pClearPreview()
    {
        if (panelPreview.list == list)
        {
            panelPreview.clearInstant();
        }
        else if (panelCover.list == list)
        {
            panelCover.clearItem();
        }
    }

    //---------------------------------------------------------------------------------------------

    function pIndexFromPosition(pos)
    {
        return pos / itemSize;
    }

    //---------------------------------------------------------------------------------------------

    function pRemove(indexes, animate)
    {
        pProcessRemove(playlist);

        indexContextual = -1;

        if (animate)
        {
            for (var i = 0; i < indexes.length; i++)
            {
                var item = itemAt(indexes[i]);

                if (item) item.animateRemove();
            }

            pIndexes = indexes;

            timer.start();
        }
        else playlist.removeTracks(indexes);
    }

    function pProcessRemove(playlist)
    {
        if (pIndexes == null) return;

        timer.stop();

        playlist.removeTracks(pIndexes);

        pIndexes = null;
    }

    //---------------------------------------------------------------------------------------------

    function pSaveScroll(playlist)
    {
        if (scrollArea == null) return;

        playlist.scrollValue = scrollArea.value / itemSize;
    }

    function pRestoreScroll()
    {
        if (scrollArea == null || playlist == null) return;

        if (playlist.scrollValue)
        {
             scrollArea.value = playlist.scrollValue * itemSize;
        }
        else scrollArea.scrollToTop();
    }

    //---------------------------------------------------------------------------------------------
    // Childs
    //---------------------------------------------------------------------------------------------

    Timer
    {
        id: timer

        interval: st.duration_normal

        onTriggered: pProcessRemove(playlist)
    }

    BaseButtonPiano
    {
        id: overlay

        width : st.dp42 + borderSizeWidth
        height: itemSize

        y: indexHover * itemSize

        borderBottom: borderSize

        visible: (enablePreview && itemHovered != null && playlist.trackIsValid(indexHover))

        isHovered: true
        isPressed: (pressedButtons & Qt.LeftButton)

        acceptedButtons: Qt.LeftButton | Qt.RightButton

        highlighted: true
        checked    : panelCover.isExpanded

        borderColor:
        {
            if (itemHovered != null && itemHovered.isDefault)
            {
                 return st.itemList_colorBorderDefault;
            }
            else return st.itemList_colorBorder;
        }

        background.visible: containsMouse
        borders   .visible: background.visible

        background.opacity: 0.8

        onEntered:
        {
            if (itemHovered == null)
            {
                if (panelPreview.list == list && panelPreview.item)
                {
                    panelPreview.show();
                }

                return;
            }

            indexPreview = indexHover;

            if (panelCover.isExpanded)
            {
                 panelCover.setItem(list);
            }
            else panelPreview.activatePlaylist(list);
        }

        onExited:
        {
            panelPreview.clear();

            panelCover.clearItemLater();
        }

        onPressed:
        {
            if ((mouse.button & Qt.LeftButton) == false) return;

            if (playlist.trackIsDefault(indexHover))
            {
                playlist.loadTracks(indexHover, 10);

                return;
            }

            indexPreview = indexHover;

            if (panelCover.isExpanded)
            {
                panelCover.clearItem();

                panelPreview.activatePlaylist(list);

                panelPreview.showInstant();
            }
            else
            {
                panelCover.setItem(list);

                panelPreview.clearInstant();
            }
        }

        Behavior on background.visible
        {
            enabled: overlay.background.visible

            PropertyAnimation { duration: st.duration_faster }
        }
    }

    Icon
    {
        anchors.left: overlay.left
        anchors.top : overlay.top

        anchors.leftMargin: st.dp5

        visible: overlay.background.visible

        source    : st.icon32x32_search
        sourceSize: st.size32x32

        iconStyle: Sk.IconRaised
    }

    CheckBox
    {
        id: checkBox

        anchors.right:
        {
            if (buttonContextual.visible)
            {
                return buttonContextual.left;
            }
            else if (buttonLink.visible)
            {
                return buttonLink.left;
            }
            else return parent.right;
        }

        anchors.top: buttonContextual.top

        anchors.rightMargin: 0
        anchors.topMargin  : st.dp3

        visible: (gui.dragList != list && itemWatcher.visible && timer.running == false)

        onCheckClicked:
        {
            if (playlist == null) return;

            if (checked)
            {
                focusList();

                playlist.selectTrack(indexHover);

                pUpdateCurrentTrack(indexHover);
            }
            else
            {
                if (playlist.selectedCount == 1)
                {
                    window.clearFocus();
                }

                playlist.unselectTrack(indexHover);
            }
        }
    }

    ButtonPushIcon
    {
        id: buttonContextual

        anchors.right: (buttonLink.visible) ? buttonLink.left
                                            : parent.right

        anchors.rightMargin: st.dp4

        width : st.dp28
        height: st.dp28

        y: itemWatcher.y + st.dp2

        visible: (enableContextual && checkBox.visible)

        checked: (indexContextual != -1)

        icon          : st.icon16x16_contextualDown
        iconSourceSize: st.size16x16

        onPressed: showPanel(indexHover)
    }

    ButtonPianoIcon
    {
        id: buttonLink

        anchors.right: parent.right

        anchors.rightMargin: (scrollArea && scrollArea.isScrollable) ? 0 : st.dp16

        width : st.dp30 + borderSizeWidth
        height: st.dp32

        y: itemWatcher.y

        borderLeft: borderSize

        borderRight: (anchors.rightMargin) ? borderSize : 0

        visible: (enableLink && checkBox.visible)

        icon          : st.icon24x24_goRelated
        iconSourceSize: st.size24x24

        borderColor: overlay.borderColor

        onClicked: link(indexActive)
    }

    Item
    {
        id: itemWatcher

        anchors.left : parent.left
        anchors.right: parent.right

        height: itemSize

        y: (indexActive != -1) ? indexActive * itemSize : 0

        visible: (indexActive != -1)
    }
}
