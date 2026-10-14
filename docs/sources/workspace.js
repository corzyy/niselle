import Clutter from 'gi://Clutter';
import GLib from 'gi://GLib';
import GObject from 'gi://GObject';
import Graphene from 'gi://Graphene';
import Meta from 'gi://Meta';
import Shell from 'gi://Shell';
import St from 'gi://St';

import * as Background from './background.js';
import * as DND from './dnd.js';
import * as Main from './main.js';
import * as OverviewControls from './overviewControls.js';
import * as Params from '../misc/params.js';

import * as Util from '../misc/util.js';
import {WindowPreview} from './windowPreview.js';

const WINDOW_PREVIEW_MAXIMUM_SCALE = 0.95;

const WINDOW_REPOSITIONING_DELAY = 750;

const LAYOUT_SCALE_WEIGHT = 1;
const LAYOUT_SPACE_WEIGHT = 0.1;

const BACKGROUND_CORNER_RADIUS_PIXELS = 30;


export class LayoutStrategy {
    constructor(params) {
        params = Params.parse(params, {
            monitor: null,
            rowSpacing: 0,
            columnSpacing: 0,
        });

        if (!params.monitor)
            throw new Error(`No monitor param passed to ${this.constructor.name}`);

        this._monitor = params.monitor;
        this._rowSpacing = params.rowSpacing;
        this._columnSpacing = params.columnSpacing;
    }

    computeLayout(_windows, _layoutParams) {
        throw new GObject.NotImplementedError(`computeLayout in ${this.constructor.name}`);
    }

    computeScaleAndSpace(_layout, _area) {
        throw new GObject.NotImplementedError(`computeScaleAndSpace in ${this.constructor.name}`);
    }

    computeWindowSlots(_layout, _area) {
        throw new GObject.NotImplementedError(`computeWindowSlots in ${this.constructor.name}`);
    }
}

class UnalignedLayoutStrategy extends LayoutStrategy {
    _newRow() {
        return {
            x: 0, y: 0,
            width: 0, height: 0,
            fullWidth: 0, fullHeight: 0,
            windows: [],
        };
    }

    _computeWindowScale(window) {
        const ratio = window.boundingBox.height / this._monitor.height;


        return Util.lerp(1.5, 1, ratio);
    }

    _computeRowSizes(layout) {
        const {rows, scale} = layout;
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            row.width = row.fullWidth * scale + (row.windows.length - 1) * this._columnSpacing;
            row.height = row.fullHeight * scale;
        }
    }

    _keepSameRow(row, window, width, idealRowWidth) {
        if (row.fullWidth + width <= idealRowWidth)
            return true;

        const oldRatio = row.fullWidth / idealRowWidth;
        const newRatio = (row.fullWidth + width) / idealRowWidth;

        if (Math.abs(1 - newRatio) < Math.abs(1 - oldRatio))
            return true;

        return false;
    }

    _sortRow(row) {
        row.windows.sort((a, b) => a.windowCenter.x - b.windowCenter.x);
    }

    computeLayout(windows, layoutParams) {
        layoutParams = Params.parse(layoutParams, {
            numRows: 0,
        });

        if (layoutParams.numRows === 0)
            throw new Error(`${this.constructor.name}: No numRows given in layout params`);

        const numRows = layoutParams.numRows;

        const rows = [];
        let totalWidth = 0;
        for (let i = 0; i < windows.length; i++) {
            const window = windows[i];
            const s = this._computeWindowScale(window);
            totalWidth += window.boundingBox.width * s;
        }

        const idealRowWidth = totalWidth / numRows;

        const sortedWindows = windows.slice();
        sortedWindows.sort((a, b) => a.windowCenter.y - b.windowCenter.y);

        let windowIdx = 0;
        for (let i = 0; i < numRows; i++) {
            const row = this._newRow();
            rows.push(row);

            for (; windowIdx < sortedWindows.length; windowIdx++) {
                const window = sortedWindows[windowIdx];
                const s = this._computeWindowScale(window);
                const width = window.boundingBox.width * s;
                const height = window.boundingBox.height * s;
                row.fullHeight = Math.max(row.fullHeight, height);

                if (this._keepSameRow(row, window, width, idealRowWidth) || (i === numRows - 1)) {
                    row.windows.push(window);
                    row.fullWidth += width;
                } else {
                    break;
                }
            }
        }

        let gridHeight = 0;
        let maxRow;
        for (let i = 0; i < numRows; i++) {
            const row = rows[i];
            this._sortRow(row);

            if (!maxRow || row.fullWidth > maxRow.fullWidth)
                maxRow = row;
            gridHeight += row.fullHeight;
        }

        return {
            numRows,
            rows,
            maxColumns: maxRow.windows.length,
            gridWidth: maxRow.fullWidth,
            gridHeight,
        };
    }

    computeScaleAndSpace(layout, area) {
        const hspacing = (layout.maxColumns - 1) * this._columnSpacing;
        const vspacing = (layout.numRows - 1) * this._rowSpacing;

        const spacedWidth = area.width - hspacing;
        const spacedHeight = area.height - vspacing;

        const horizontalScale = spacedWidth / layout.gridWidth;
        const verticalScale = spacedHeight / layout.gridHeight;

        const scale = Math.min(
            horizontalScale, verticalScale, WINDOW_PREVIEW_MAXIMUM_SCALE);

        const scaledLayoutWidth = layout.gridWidth * scale + hspacing;
        const scaledLayoutHeight = layout.gridHeight * scale + vspacing;
        const space = (scaledLayoutWidth * scaledLayoutHeight) / (area.width * area.height);

        layout.scale = scale;

        return [scale, space];
    }

    computeWindowSlots(layout, area) {
        this._computeRowSizes(layout);

        const {rows, scale} = layout;

        const slots = [];

        let heightWithoutSpacing = 0;
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            heightWithoutSpacing += row.height;
        }

        const verticalSpacing = (rows.length - 1) * this._rowSpacing;
        const additionalVerticalScale = Math.min(1, (area.height - verticalSpacing) / heightWithoutSpacing);

        let compensation = 0;
        let y = 0;

        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];

            const horizontalSpacing = (row.windows.length - 1) * this._columnSpacing;
            const widthWithoutSpacing = row.width - horizontalSpacing;
            const additionalHorizontalScale = Math.min(1, (area.width - horizontalSpacing) / widthWithoutSpacing);

            if (additionalHorizontalScale < additionalVerticalScale) {
                row.additionalScale = additionalHorizontalScale;
                compensation += (additionalVerticalScale - additionalHorizontalScale) * row.height;
            } else {
                row.additionalScale = additionalVerticalScale;
            }

            row.x = area.x + (Math.max(area.width - (widthWithoutSpacing * row.additionalScale + horizontalSpacing), 0) / 2);
            row.y = area.y + (Math.max(area.height - (heightWithoutSpacing + verticalSpacing), 0) / 2) + y;
            y += row.height * row.additionalScale + this._rowSpacing;
        }

        compensation /= 2;

        for (let i = 0; i < rows.length; i++) {
            const row = rows[i];
            const rowY = row.y + compensation;
            const rowHeight = row.height * row.additionalScale;

            let x = row.x;
            for (let j = 0; j < row.windows.length; j++) {
                const window = row.windows[j];

                let s = scale * this._computeWindowScale(window) * row.additionalScale;
                const cellWidth = window.boundingBox.width * s;
                const cellHeight = window.boundingBox.height * s;

                s = Math.min(s, WINDOW_PREVIEW_MAXIMUM_SCALE);
                const cloneWidth = window.boundingBox.width * s;
                const cloneHeight = window.boundingBox.height * s;

                let cloneX = x + (cellWidth - cloneWidth) / 2;
                let cloneY;

                if (rows.length === 1)
                    cloneY = rowY + (rowHeight - cloneHeight) / 2;
                else
                    cloneY = rowY + rowHeight - cellHeight;

                cloneX = Math.floor(cloneX);
                cloneY = Math.floor(cloneY);

                slots.push([cloneX, cloneY, cloneWidth, cloneHeight, window]);
                x += cellWidth + this._columnSpacing;
            }
        }
        return slots;
    }
}

function animateAllocation(actor, box) {
    actor.save_easing_state();
    actor.set_easing_mode(Clutter.AnimationMode.EASE_OUT_QUAD);
    actor.set_easing_duration(200);

    actor.allocate(box);

    actor.restore_easing_state();

    return actor.get_transition('allocation');
}

export const WorkspaceLayout = GObject.registerClass({
    Properties: {
        'spacing': GObject.ParamSpec.double(
            'spacing', null, null,
            GObject.ParamFlags.READWRITE,
            0, Infinity, 20),
        'layout-frozen': GObject.ParamSpec.boolean(
            'layout-frozen', null, null,
            GObject.ParamFlags.READWRITE,
            false),
    },
}, class WorkspaceLayout extends Clutter.LayoutManager {
    _init(metaWorkspace, monitorIndex, overviewAdjustment) {
        super._init();

        this._spacing = 20;
        this._layoutFrozen = false;

        this._metaWorkspace = metaWorkspace;
        this._monitorIndex = monitorIndex;
        this._overviewAdjustment = overviewAdjustment;

        this._container = null;
        this._windows = new Map();
        this._sortedWindows = [];
        this._lastBox = null;
        this._windowSlots = [];
        this._layout = null;

        this._needsLayout = true;

        this._stateAdjustment = new St.Adjustment({
            value: 0,
            lower: 0,
            upper: 1,
        });

        this._stateAdjustment.connect('notify::value', () => {
            this._syncOpacities();
            this.syncOverlays();
            this.layout_changed();
        });

        this._workarea = null;
        this._workareasChangedId = 0;
    }

    _syncOpacity(actor, metaWindow) {
        if (!metaWindow.showing_on_its_workspace())
            actor.opacity = this._stateAdjustment.value * 255;
    }

    _syncOpacities() {
        this._windows.forEach(({metaWindow}, actor) => {
            this._syncOpacity(actor, metaWindow);
        });
    }

    _isBetterScaleAndSpace(oldScale, oldSpace, scale, space) {
        const spacePower = (space - oldSpace) * LAYOUT_SPACE_WEIGHT;
        const scalePower = (scale - oldScale) * LAYOUT_SCALE_WEIGHT;

        if (scale > oldScale && space > oldSpace) {
            return true;
        } else if (scale > oldScale && space <= oldSpace) {
            return scalePower > spacePower;
        } else if (scale <= oldScale && space > oldSpace) {
            return spacePower > scalePower;
        } else {
            return false;
        }
    }

    _adjustSpacingAndPadding(rowSpacing, colSpacing, containerBox) {
        if (this._sortedWindows.length === 0)
            return [rowSpacing, colSpacing, containerBox];

        const window = this._sortedWindows[0];

        const [topOversize, bottomOversize] = window.chromeHeights();
        const [leftOversize, rightOversize] = window.chromeWidths();

        const oversize =
            Math.max(topOversize, bottomOversize, leftOversize, rightOversize);

        if (rowSpacing !== null)
            rowSpacing += oversize;
        if (colSpacing !== null)
            colSpacing += oversize;

        if (containerBox) {
            const monitor = Main.layoutManager.monitors[this._monitorIndex];

            const bottomPoint = new Graphene.Point3D({y: containerBox.y2});
            const transformedBottomPoint =
                this._container.apply_transform_to_point(bottomPoint);
            const bottomFreeSpace =
                (monitor.y + monitor.height) - transformedBottomPoint.y;

            const [, bottomOverlap] = window.overlapHeights();

            if ((bottomOverlap + oversize) > bottomFreeSpace)
                containerBox.y2 -= (bottomOverlap + oversize) - bottomFreeSpace;
        }

        return [rowSpacing, colSpacing, containerBox];
    }

    _createBestLayout(area) {
        const [rowSpacing, columnSpacing] =
            this._adjustSpacingAndPadding(this._spacing, this._spacing, null);

        this._layoutStrategy = new UnalignedLayoutStrategy({
            monitor: Main.layoutManager.monitors[this._monitorIndex],
            rowSpacing,
            columnSpacing,
        });

        let lastLayout = null;
        let lastNumColumns = -1;
        let lastScale = 0;
        let lastSpace = 0;

        for (let numRows = 1; ; numRows++) {
            const numColumns = Math.ceil(this._sortedWindows.length / numRows);

            if (numColumns === lastNumColumns)
                break;

            const layout = this._layoutStrategy.computeLayout(this._sortedWindows, {
                numRows,
            });

            const [scale, space] = this._layoutStrategy.computeScaleAndSpace(layout, area);

            if (lastLayout && !this._isBetterScaleAndSpace(lastScale, lastSpace, scale, space))
                break;

            lastLayout = layout;
            lastNumColumns = numColumns;
            lastScale = scale;
            lastSpace = space;
        }

        return lastLayout;
    }

    _getWindowSlots(containerBox) {
        [, , containerBox] =
            this._adjustSpacingAndPadding(null, null, containerBox);

        const availArea = {
            x: parseInt(containerBox.x1),
            y: parseInt(containerBox.y1),
            width: parseInt(containerBox.get_width()),
            height: parseInt(containerBox.get_height()),
        };

        return this._layoutStrategy.computeWindowSlots(this._layout, availArea);
    }

    _getAdjustedWorkarea(container) {
        const workarea = this._workarea.copy();

        if (container instanceof St.Widget) {
            const themeNode = container.get_theme_node();
            workarea.width -= themeNode.get_horizontal_padding();
            workarea.height -= themeNode.get_vertical_padding();
        }

        return workarea;
    }

    _syncWorkareaTracking() {
        if (this._container) {
            if (this._workAreaChangedId)
                return;
            this._workarea = Main.layoutManager.getWorkAreaForMonitor(this._monitorIndex);
            this._workareasChangedId =
                global.display.connect('workareas-changed', () => {
                    this._workarea = Main.layoutManager.getWorkAreaForMonitor(this._monitorIndex);
                    this.layout_changed();
                });
        } else if (this._workareasChangedId) {
            global.display.disconnect(this._workareasChangedId);
            this._workareasChangedId = 0;
        }
    }

    vfunc_set_container(container) {
        this._container = container;
        this._syncWorkareaTracking();
        this._stateAdjustment.actor = container;
    }

    vfunc_get_preferred_width(container, forHeight) {
        const workarea = this._getAdjustedWorkarea(container);
        if (forHeight === -1)
            return [0, workarea.width];

        const workAreaAspectRatio = workarea.width / workarea.height;
        const widthPreservingAspectRatio = forHeight * workAreaAspectRatio;

        return [0, widthPreservingAspectRatio];
    }

    vfunc_get_preferred_height(container, forWidth) {
        const workarea = this._getAdjustedWorkarea(container);
        if (forWidth === -1)
            return [0, workarea.height];

        const workAreaAspectRatio = workarea.width / workarea.height;
        const heightPreservingAspectRatio = forWidth / workAreaAspectRatio;

        return [0, heightPreservingAspectRatio];
    }

    vfunc_allocate(container, box) {
        const containerBox = container.allocation;
        const [containerWidth, containerHeight] = containerBox.get_size();
        const containerAllocationChanged =
            this._lastBox === null || !this._lastBox.equal(containerBox);

        if (this._layoutFrozen && containerAllocationChanged && !Main.overview.animationInProgress) {
            this._layoutFrozen = false;
            this.notify('layout-frozen');
        }

        const {ControlsState} = OverviewControls;
        const {currentState} =
            this._overviewAdjustment.getStateTransitionParams();
        const inSessionTransition = currentState <= ControlsState.WINDOW_PICKER;

        const window = this._sortedWindows[0];

        if (inSessionTransition || !window) {
            container.remove_clip();
        } else {
            const [, bottomOversize] = window.chromeHeights();
            const [containerX, containerY] = containerBox.get_origin();

            const extraHeightProgress =
                currentState - OverviewControls.ControlsState.WINDOW_PICKER;

            const extraClipHeight = bottomOversize * (1 - extraHeightProgress);

            container.set_clip(containerX, containerY,
                containerWidth, containerHeight + extraClipHeight);
        }

        let layoutChanged = false;
        if (!this._layoutFrozen || !this._lastBox) {
            if (this._needsLayout) {
                this._layout = this._createBestLayout(this._workarea);
                this._needsLayout = false;
                layoutChanged = true;
            }

            if (layoutChanged || containerAllocationChanged) {
                this._windowSlotsBox = box.copy();
                this._windowSlots = this._getWindowSlots(this._windowSlotsBox);
            }
        }

        const slotsScale = box.get_width() / this._windowSlotsBox.get_width();
        const workareaX = this._workarea.x;
        const workareaY = this._workarea.y;
        const workareaWidth = this._workarea.width;
        const stateAdjustementValue = this._stateAdjustment.value;

        const allocationScale = containerWidth / workareaWidth;

        const childBox = new Clutter.ActorBox();

        const nSlots = this._windowSlots.length;
        for (let i = 0; i < nSlots; i++) {
            let [x, y, width, height, child] = this._windowSlots[i];
            if (!child.visible)
                continue;

            x *= slotsScale;
            y *= slotsScale;
            width *= slotsScale;
            height *= slotsScale;

            const windowInfo = this._windows.get(child);

            let workspaceBoxX, workspaceBoxY;
            let workspaceBoxWidth, workspaceBoxHeight;

            if (windowInfo.metaWindow.showing_on_its_workspace()) {
                const {boundingBox} = child;
                workspaceBoxX = (boundingBox.x - workareaX) * allocationScale;
                workspaceBoxY = (boundingBox.y - workareaY) * allocationScale;
                workspaceBoxWidth = boundingBox.width * allocationScale;
                workspaceBoxHeight = boundingBox.height * allocationScale;
            } else {
                workspaceBoxX = workareaX * allocationScale;
                workspaceBoxY = workareaY * allocationScale;
                workspaceBoxWidth = 0;
                workspaceBoxHeight = 0;
            }

            if (inSessionTransition) {
                workspaceBoxWidth = Math.max(workspaceBoxWidth, width);
                workspaceBoxHeight = Math.max(workspaceBoxHeight, height);
            }

            x = Util.lerp(workspaceBoxX, x, stateAdjustementValue);
            y = Util.lerp(workspaceBoxY, y, stateAdjustementValue);
            width = Util.lerp(workspaceBoxWidth, width, stateAdjustementValue);
            height = Util.lerp(workspaceBoxHeight, height, stateAdjustementValue);

            childBox.set_origin(x, y);
            childBox.set_size(width, height);

            if (windowInfo.currentTransition) {
                windowInfo.currentTransition.get_interval().set_final(childBox);

                child.allocate(child.allocation);
                continue;
            }

            if (layoutChanged && !Main.overview.animationInProgress) {
                const transition = animateAllocation(child, childBox);
                if (transition) {
                    windowInfo.currentTransition = transition;
                    windowInfo.currentTransition.connect('stopped', () => {
                        windowInfo.currentTransition = null;
                    });
                }
            } else {
                child.allocate(childBox);
            }
        }

        this._lastBox = containerBox.copy();
    }

    _syncOverlay(preview) {
        const active = this._metaWorkspace?.active ?? true;
        preview.overlayEnabled = active && this._stateAdjustment.value === 1;
    }

    syncOverlays() {
        [...this._windows.keys()].forEach(preview => this._syncOverlay(preview));
    }

    addWindow(window, metaWindow) {
        if (this._windows.has(window))
            return;

        this._windows.set(window, {
            metaWindow,
            sizeChangedId: metaWindow.connect('size-changed', () => {
                this._needsLayout = true;
                this.layout_changed();
            }),
            destroyId: window.connect('destroy', () =>
                this.removeWindow(window)),
            currentTransition: null,
        });

        this._sortedWindows.push(window);
        this._sortedWindows.sort((a, b) => {
            const winA = this._windows.get(a).metaWindow;
            const winB = this._windows.get(b).metaWindow;

            return winA.get_stable_sequence() - winB.get_stable_sequence();
        });

        this._syncOpacity(window, metaWindow);
        this._syncOverlay(window);
        this._container.add_child(window);

        this._needsLayout = true;
        this.layout_changed();
    }

    removeWindow(window) {
        const windowInfo = this._windows.get(window);
        if (!windowInfo)
            return;

        windowInfo.metaWindow.disconnect(windowInfo.sizeChangedId);
        window.disconnect(windowInfo.destroyId);
        if (windowInfo.currentTransition)
            window.remove_transition('allocation');

        this._windows.delete(window);
        this._sortedWindows.splice(this._sortedWindows.indexOf(window), 1);

        const index = this._windowSlots.findIndex(s => s[4] === window);
        if (index !== -1)
            this._windowSlots.splice(index, 1);

        if (window.get_parent() === this._container)
            this._container.remove_child(window);

        this._needsLayout = true;
        this.layout_changed();
    }

    syncStacking(stackIndices) {
        const windows = [...this._windows.keys()];
        windows.sort((a, b) => {
            const seqA = this._windows.get(a).metaWindow.get_stable_sequence();
            const seqB = this._windows.get(b).metaWindow.get_stable_sequence();

            return stackIndices[seqA] - stackIndices[seqB];
        });

        let lastWindow = null;
        for (const window of windows) {
            window.setStackAbove(lastWindow);
            lastWindow = window;
        }

        this._needsLayout = true;
        this.layout_changed();
    }

    getFocusChain() {
        if (this._stateAdjustment.value === 0)
            return [];

        return this._windowSlots.map(s => s[4]);
    }

    get stateAdjustment() {
        return this._stateAdjustment;
    }

    get spacing() {
        return this._spacing;
    }

    set spacing(s) {
        if (this._spacing === s)
            return;

        this._spacing = s;

        this._needsLayout = true;
        this.notify('spacing');
        this.layout_changed();
    }

    get layoutFrozen() {
        return this._layoutFrozen;
    }

    set layoutFrozen(f) {
        if (this._layoutFrozen === f)
            return;

        this._layoutFrozen = f;

        this.notify('layout-frozen');
        if (!this._layoutFrozen)
            this.layout_changed();
    }
});

export const WorkspaceBackground = GObject.registerClass(
class WorkspaceBackground extends Shell.WorkspaceBackground {
    _init(monitorIndex, stateAdjustment) {
        super._init({
            style_class: 'workspace-background',
            x_expand: true,
            y_expand: true,
            monitor_index: monitorIndex,
        });

        this._monitorIndex = monitorIndex;
        this._workarea = Main.layoutManager.getWorkAreaForMonitor(monitorIndex);

        this._stateAdjustment = stateAdjustment;
        this._stateAdjustment.connectObject('notify::value', () => {
            this._updateBorderRadius();
            this.queue_relayout();
        }, this);
        this._stateAdjustment.bind_property(
            'value', this, 'state-adjustment-value',
            GObject.BindingFlags.SYNC_CREATE
        );

        this._bin = new Clutter.Actor({
            layout_manager: new Clutter.BinLayout(),
            clip_to_allocation: true,
        });

        this._backgroundGroup = new Meta.BackgroundGroup({
            layout_manager: new Clutter.BinLayout(),
            x_expand: true,
            y_expand: true,
        });
        this._bin.add_child(this._backgroundGroup);
        this.add_child(this._bin);

        this._bgManager = new Background.BackgroundManager({
            container: this._backgroundGroup,
            monitorIndex: this._monitorIndex,
            controlPosition: false,
            useContentSize: false,
        });

        this._bgManager.connect('changed', () => {
            this._updateRoundedClipBounds();
            this._updateBorderRadius();
        });

        global.display.connectObject('workareas-changed', () => {
            this._workarea = Main.layoutManager.getWorkAreaForMonitor(monitorIndex);
            this._updateRoundedClipBounds();
            this.queue_relayout();
        }, this);
        this._updateRoundedClipBounds();

        this._updateBorderRadius();

        this.connect('destroy', this._onDestroy.bind(this));
    }

    _updateBorderRadius() {
        const {scaleFactor} = St.ThemeContext.get_for_stage(global.stage);
        const cornerRadius = scaleFactor * BACKGROUND_CORNER_RADIUS_PIXELS;

        const backgroundContent = this._bgManager.backgroundActor.content;
        backgroundContent.rounded_clip_radius =
            Util.lerp(0, cornerRadius, this._stateAdjustment.value);
    }

    _updateRoundedClipBounds() {
        const monitor = Main.layoutManager.monitors[this._monitorIndex];

        const rect = new Graphene.Rect();
        rect.origin.x = this._workarea.x - monitor.x;
        rect.origin.y = this._workarea.y - monitor.y;
        rect.size.width = this._workarea.width;
        rect.size.height = this._workarea.height;

        this._bgManager.backgroundActor.content.set_rounded_clip_bounds(rect);
    }

    _onDestroy() {
        if (this._bgManager) {
            this._bgManager.destroy();
            this._bgManager = null;
        }
    }
});

export const Workspace = GObject.registerClass(
class Workspace extends St.Widget {
    _init(metaWorkspace, monitorIndex, overviewAdjustment) {
        super._init({
            style_class: 'window-picker',
            pivot_point: new Graphene.Point({x: 0.5, y: 0.5}),
            layout_manager: new Clutter.BinLayout(),
        });

        const layoutManager = new WorkspaceLayout(metaWorkspace, monitorIndex,
            overviewAdjustment);

        this._background =
            new WorkspaceBackground(monitorIndex, layoutManager.stateAdjustment);
        this.add_child(this._background);

        this._container = new Clutter.Actor({
            reactive: true,
            x_expand: true,
            y_expand: true,
        });
        this._container.layout_manager = layoutManager;
        this.add_child(this._container);

        this.metaWorkspace = metaWorkspace;

        this._overviewAdjustment = overviewAdjustment;

        this.monitorIndex = monitorIndex;
        this._monitor = Main.layoutManager.monitors[this.monitorIndex];

        if (monitorIndex !== Main.layoutManager.primaryIndex)
            this.add_style_class_name('external-monitor');

        const clickGesture = new Clutter.ClickGesture({
            required_button: Clutter.BUTTON_PRIMARY,
        });
        clickGesture.connect('recognize', () => {
            const leaveOverview = this._shouldLeaveOverview();

            this.metaWorkspace?.activate(global.get_current_time());
            if (leaveOverview)
                Main.overview.hide();
        });
        this.bind_property('mapped', clickGesture, 'enabled', GObject.BindingFlags.SYNC_CREATE);
        this._container.add_action(clickGesture);

        this.connect('style-changed', this._onStyleChanged.bind(this));
        this.connect('destroy', this._onDestroy.bind(this));

        this._skipTaskbarSignals = new Map();
        this._windows = [];
        this._layoutFrozenId = 0;

        this._delegate = this;

        this.metaWorkspace?.connectObject(
            'window-added', this._windowAdded.bind(this), GObject.ConnectFlags.AFTER,
            'window-removed', this._windowRemoved.bind(this), GObject.ConnectFlags.AFTER,
            'notify::active', () => layoutManager.syncOverlays(), this);
        global.display.connectObject(
            'window-entered-monitor', this._windowEnteredMonitor.bind(this), GObject.ConnectFlags.AFTER,
            'window-left-monitor', this._windowLeftMonitor.bind(this), GObject.ConnectFlags.AFTER,
            this);

        global.get_window_actors().map(a => this._doAddWindow(a.meta_window));
    }

    _shouldLeaveOverview() {
        if (!this.metaWorkspace || this.metaWorkspace.active)
            return true;

        const overviewState = this._overviewAdjustment.value;
        return overviewState > OverviewControls.ControlsState.WINDOW_PICKER;
    }

    vfunc_get_focus_chain() {
        return this._container.layout_manager.getFocusChain();
    }

    _lookupIndex(metaWindow) {
        return this._windows.findIndex(w => w.metaWindow === metaWindow);
    }

    containsMetaWindow(metaWindow) {
        return this._lookupIndex(metaWindow) >= 0;
    }

    isEmpty() {
        return this._windows.length === 0;
    }

    syncStacking(stackIndices) {
        this._container.layout_manager.syncStacking(stackIndices);
    }

    _doRemoveWindow(metaWin) {
        const clone = this._removeWindowClone(metaWin);

        if (!clone)
            return;

        clone.destroy();

        this._container.layout_manager.layout_frozen = true;

        if (this._layoutFrozenId > 0) {
            GLib.source_remove(this._layoutFrozenId);
            this._layoutFrozenId = 0;
        }

        let [oldX, oldY] = global.get_pointer();

        this._layoutFrozenId = GLib.timeout_add(
            GLib.PRIORITY_DEFAULT,
            WINDOW_REPOSITIONING_DELAY,
            () => {
                const [newX, newY] = global.get_pointer();
                const pointerHasMoved = oldX !== newX || oldY !== newY;
                const actorUnderPointer = global.stage.get_actor_at_pos(
                    Clutter.PickMode.REACTIVE, newX, newY);

                if ((pointerHasMoved && this.contains(actorUnderPointer)) ||
                    this._windows.some(w => w.contains(actorUnderPointer))) {
                    oldX = newX;
                    oldY = newY;
                    return GLib.SOURCE_CONTINUE;
                }

                this._container.layout_manager.layout_frozen = false;
                this._layoutFrozenId = 0;
                return GLib.SOURCE_REMOVE;
            });

        GLib.Source.set_name_by_id(this._layoutFrozenId,
            '[gnome-shell] this._layoutFrozenId');
    }

    _doAddWindow(metaWin) {
        const win = metaWin.get_compositor_private();

        if (!win) {
            const id = GLib.idle_add_once(GLib.PRIORITY_DEFAULT, () => {
                if (metaWin.get_compositor_private() &&
                    metaWin.get_workspace() === this.metaWorkspace)
                    this._doAddWindow(metaWin);
            });
            GLib.Source.set_name_by_id(id, '[gnome-shell] this._doAddWindow');
            return;
        }

        if (this.containsMetaWindow(metaWin))
            return;

        if (!this._isMyWindow(metaWin))
            return;

        this._skipTaskbarSignals.set(metaWin,
            metaWin.connect('notify::skip-taskbar', () => {
                if (metaWin.skip_taskbar)
                    this._doRemoveWindow(metaWin);
                else
                    this._doAddWindow(metaWin);
            }));

        if (!this._isOverviewWindow(metaWin)) {
            if (metaWin.get_transient_for() == null)
                return;

            const parent = metaWin.find_root_ancestor();
            const clone = this._windows.find(c => c.metaWindow === parent);

            if (clone)
                clone.addDialog(metaWin);

            return;
        }

        const clone = this._addWindowClone(metaWin);

        clone.set_pivot_point(0.5, 0.5);
        clone.scale_x = 0;
        clone.scale_y = 0;
        clone.ease({
            scale_x: 1,
            scale_y: 1,
            duration: 250,
            onStopped: () => clone.set_pivot_point(0, 0),
        });

        if (this._layoutFrozenId > 0) {
            this._container.layout_manager.layout_frozen = false;

            GLib.source_remove(this._layoutFrozenId);
            this._layoutFrozenId = 0;
        }
    }

    _windowAdded(metaWorkspace, metaWin) {
        if (!Main.overview.closing)
            this._doAddWindow(metaWin);
    }

    _windowRemoved(metaWorkspace, metaWin) {
        this._doRemoveWindow(metaWin);
    }

    _windowEnteredMonitor(metaDisplay, monitorIndex, metaWin) {
        if (monitorIndex === this.monitorIndex && !Main.overview.closing)
            this._doAddWindow(metaWin);
    }

    _windowLeftMonitor(metaDisplay, monitorIndex, metaWin) {
        if (monitorIndex === this.monitorIndex)
            this._doRemoveWindow(metaWin);
    }

    hasMaximizedWindows() {
        return this._windows.some(w => {
            const {metaWindow} = w;
            return metaWindow.showing_on_its_workspace() &&
                   metaWindow.is_maximized();
        });
    }

    _clearSkipTaskbarSignals() {
        for (const [metaWin, id] of this._skipTaskbarSignals)
            metaWin.disconnect(id);
        this._skipTaskbarSignals.clear();
    }

    prepareToLeaveOverview() {
        this._clearSkipTaskbarSignals();

        for (let i = 0; i < this._windows.length; i++)
            this._windows[i].remove_all_transitions();

        if (this._layoutFrozenId > 0) {
            GLib.source_remove(this._layoutFrozenId);
            this._layoutFrozenId = 0;
        }

        this._container.layout_manager.layout_frozen = true;
        Main.overview.connectObject(
            'hidden', this._doneLeavingOverview.bind(this), this);
    }

    _onDestroy() {
        this._clearSkipTaskbarSignals();

        if (this._layoutFrozenId > 0) {
            GLib.source_remove(this._layoutFrozenId);
            this._layoutFrozenId = 0;
        }

        this._windows = [];
    }

    _doneLeavingOverview() {
        this._container.layout_manager.layout_frozen = false;
    }

    _doneShowingOverview() {
        this._container.layout_manager.layout_frozen = false;
    }

    _isMyWindow(window) {
        const isOnWorkspace = this.metaWorkspace === null ||
            window.located_on_workspace(this.metaWorkspace);
        const isOnMonitor = window.get_monitor() === this.monitorIndex;

        return isOnWorkspace && isOnMonitor;
    }

    _isOverviewWindow(window) {
        return !window.skip_taskbar;
    }

    _addWindowClone(metaWindow) {
        const clone = new WindowPreview(metaWindow, this, this._overviewAdjustment);

        clone.connect('selected',
            this._onCloneSelected.bind(this));
        clone.connect('drag-begin', () => {
            Main.overview.beginWindowDrag(metaWindow);
        });
        clone.connect('drag-cancelled', () => {
            Main.overview.cancelledWindowDrag(metaWindow);
        });
        clone.connect('drag-end', () => {
            Main.overview.endWindowDrag(metaWindow);
        });
        clone.connect('show-chrome', () => {
            const focus = global.stage.key_focus;
            if (focus == null || this.contains(focus))
                clone.grab_key_focus();

            this._windows.forEach(c => {
                if (c !== clone)
                    c.hideOverlay(true);
            });
        });
        clone.connect('destroy', () => {
            this._doRemoveWindow(metaWindow);
        });

        this._container.layout_manager.addWindow(clone, metaWindow);

        if (this._windows.length === 0)
            clone.setStackAbove(null);
        else
            clone.setStackAbove(this._windows[this._windows.length - 1]);

        this._windows.push(clone);

        return clone;
    }

    _removeWindowClone(metaWin) {
        const index = this._lookupIndex(metaWin);

        if (index === -1)
            return null;

        this._container.layout_manager.removeWindow(this._windows[index]);

        return this._windows.splice(index, 1).pop();
    }

    _onStyleChanged() {
        const themeNode = this.get_theme_node();
        this._container.layout_manager.spacing = themeNode.get_length('spacing');
    }

    _onCloneSelected(clone, time) {
        const wsIndex = this.metaWorkspace?.index();

        if (this._shouldLeaveOverview())
            Main.activateWindow(clone.metaWindow, time, wsIndex);
        else
            this.metaWorkspace?.activate(time);
    }

    handleDragOver(source, _actor, _x, _y, _time) {
        if (source.metaWindow && !this._isMyWindow(source.metaWindow))
            return DND.DragMotionResult.MOVE_DROP;
        if (source.app && source.app.can_open_new_window())
            return DND.DragMotionResult.COPY_DROP;
        if (!source.app && source.shellWorkspaceLaunch)
            return DND.DragMotionResult.COPY_DROP;

        return DND.DragMotionResult.CONTINUE;
    }

    acceptDrop(source, actor, x, y, time) {
        const workspaceManager = global.workspace_manager;
        const workspaceIndex = this.metaWorkspace
            ? this.metaWorkspace.index()
            : workspaceManager.get_active_workspace_index();

        if (source.metaWindow) {
            const window = source.metaWindow;
            if (this._isMyWindow(window))
                return false;

            Main.moveWindowToMonitorAndWorkspace(window,
                this.monitorIndex, workspaceIndex);
            return true;
        } else if (source.app && source.app.can_open_new_window()) {
            if (source.animateLaunchAtPos)
                source.animateLaunchAtPos(actor.x, actor.y);

            source.app.open_new_window(workspaceIndex);
            return true;
        } else if (!source.app && source.shellWorkspaceLaunch) {
            source.shellWorkspaceLaunch({
                workspace: workspaceIndex,
                timestamp: time,
            });
            return true;
        }

        return false;
    }

    get stateAdjustment() {
        return this._container.layout_manager.stateAdjustment;
    }
});
