use dear_imgui_rs::{MouseButton, Ui};
use dmm::Coord;
use editor::tool::Tool;
use render::{InteractionMode, MapViewInteraction, PickRequest};

use super::{
    ViewFrame, cursor_in_map_view,
    stroke::{ActivePlacementFlash, PickStroke, PlacementStroke},
};
use crate::{
    gizmo::{GizmoMapView, transform_mutations, transform_values},
    session::{FillOutcome, PickedTransform, Session},
    settings::{KeybindAction, Settings},
    transform::anchor_to_tile,
    ui::{
        FILL_LIMIT_WARNING_POPUP, FillWarningContext, NodeOverlayView, NodeRightClick, PendingFillWarning,
        TransformMode, UiState,
        context_menu::{NodeContext, POPUP as MAP_MENU_POPUP, Target as MenuTarget},
        coop::{COMMENT_POPUP, CommentDraft},
        draw_node_overlay,
        node::NodeOverlayHit,
        node_right_click,
    },
};
use editor::{
    command::EditGroupId,
    document::{DocumentId, PrefabInstanceId},
};

#[derive(Debug, Clone, Copy)]
pub(super) struct Clicks {
    pub(super) is_left_clicked: bool,
    pub(super) is_left_down: bool,
    pub(super) is_left_double_clicked: bool,
    pub(super) is_right_clicked: bool,
}

impl Clicks {
    pub(super) fn read(ui: &Ui) -> Self {
        Self {
            is_left_clicked: ui.is_mouse_clicked(MouseButton::Left),
            is_left_down: ui.is_mouse_down(MouseButton::Left),
            is_left_double_clicked: ui.is_mouse_double_clicked(MouseButton::Left),
            is_right_clicked: ui.is_mouse_clicked(MouseButton::Right),
        }
    }
}

pub(super) fn configure_tool_interaction(tool: Tool, interaction: &mut MapViewInteraction) {
    interaction.mode = match (tool, interaction.mode) {
        (Tool::Place | Tool::Select | Tool::Fill | Tool::RectFill, _) => InteractionMode::Place,
        (Tool::Pick | Tool::Replace | Tool::Move, InteractionMode::Pick { pick }) => InteractionMode::Pick { pick },
        (Tool::Node, InteractionMode::Node { pick }) => InteractionMode::Node { pick },
        (Tool::Delete, InteractionMode::Delete { pick }) => InteractionMode::Delete { pick },
        (Tool::Pick | Tool::Replace | Tool::Comment | Tool::Move, _) => InteractionMode::Pick { pick: None },
        (Tool::Node, _) => InteractionMode::Node { pick: None },
        (Tool::Delete, _) => InteractionMode::Delete { pick: None },
    };
    match tool {
        Tool::Place | Tool::Select | Tool::Fill | Tool::RectFill | Tool::Comment => {
            interaction.cursor = None;
            interaction.picked = None;
        },
        Tool::Delete | Tool::Replace => {
            interaction.picked = None;
        },
        Tool::Pick | Tool::Node | Tool::Move => {},
    }
}

pub(super) fn interaction_mode(tool: Tool) -> InteractionMode {
    match tool {
        Tool::Place | Tool::Select | Tool::Fill | Tool::RectFill => InteractionMode::Place,
        Tool::Pick | Tool::Replace | Tool::Comment | Tool::Move => InteractionMode::Pick { pick: None },
        Tool::Node => InteractionMode::Node { pick: None },
        Tool::Delete => InteractionMode::Delete { pick: None },
    }
}

pub(super) fn request_pick(interaction: &mut MapViewInteraction, request: PickRequest) {
    match &mut interaction.mode {
        InteractionMode::Place => {},
        InteractionMode::Pick { pick } | InteractionMode::Node { pick } | InteractionMode::Delete { pick } => {
            *pick = Some(request);
        },
    }
}

pub(super) fn draw_node_hit(ui: &Ui, session: &Session, frame: &ViewFrame<'_>) -> NodeOverlayHit {
    let is_interactive = frame.is_hovered && !session.node_dragging();

    (frame.is_active && session.tool() == Tool::Node)
        .then(|| session.node_overlay())
        .flatten()
        .map(|overlay| {
            draw_node_overlay(
                ui,
                &overlay,
                NodeOverlayView {
                    camera: frame.camera,
                    viewport_min: frame.layout.viewport.min,
                    viewport_max: frame.layout.viewport.max,
                    tile_size: session.options.tile_size,
                    hovered_tile: frame.coord,
                    interactive: is_interactive,
                },
            )
        })
        .unwrap_or_default()
}

fn node_context_menu(
    session: &mut Session, frame: &ViewFrame<'_>, node_hit: &NodeOverlayHit, coord: Coord,
) -> Option<NodeContext> {
    if session.tool() != Tool::Node {
        return None;
    }

    if let Some(standalone) = node_hit.standalone {
        Some(NodeContext::Standalone(standalone))
    } else if let Some(connection) = node_hit.connection.clone() {
        Some(NodeContext::Connection(connection))
    } else if node_hit.handle.is_some() {
        None
    } else {
        frame
            .cursor
            .map(|cursor| NodeContext::Pick(coord, cursor_in_map_view(cursor, frame.layout.scale)))
    }
}

fn apply_context_menu(
    ui: &Ui, session: &mut Session, frame: &mut ViewFrame<'_>, node_hit: &NodeOverlayHit, coord: Coord,
) {
    let atoms = session
        .state
        .active_document()
        .map(|document| document.instance_ids_at(coord).to_vec())
        .unwrap_or_default();
    let node = node_context_menu(session, frame, node_hit, coord);
    let is_region_selected = session.tool() == Tool::Select
        && session
            .selection()
            .is_some_and(|selection| session.selection_mode().includes(selection, coord));
    *frame.context = Some(MenuTarget {
        document: frame.id,
        coord,
        atoms,
        node,
        region_selected: is_region_selected,
        replace_for: None,
        replace_query: String::new(),
    });
    ui.open_popup(MAP_MENU_POPUP);
}

pub(super) fn apply_right_click(
    ui: &Ui, session: &mut Session, frame: &mut ViewFrame<'_>, node_hit: &NodeOverlayHit, coord: Coord,
) {
    // node right clicks are prioritized over context menu, so they can be deleted first before context menu is open
    if let Some(right_click) = node_right_click(session.tool(), ui.io().key_shift(), node_hit) {
        match right_click {
            NodeRightClick::DeleteStandalone(node) => {
                session.delete_standalone_node(node);
            },
            NodeRightClick::DeleteConnection(connection) => {
                session.delete_node_connection(connection);
            },
        }

        return;
    }

    apply_context_menu(ui, session, frame, node_hit, coord);
}

pub(super) fn drive_node_tool(
    session: &mut Session, frame: &mut ViewFrame<'_>, node_hit: &NodeOverlayHit, clicks: Clicks, is_capturing: bool,
) {
    if !frame.is_focused {
        session.cancel_node_drag();
    }

    if !is_capturing && !session.node_dragging() {
        frame.interaction.cursor = frame
            .cursor
            .map(|cursor| cursor_in_map_view(cursor, frame.layout.scale));
        if clicks.is_left_clicked {
            if let Some(coord) = node_hit.handle {
                session.start_node_drag(coord);
            } else if frame.coord.is_some() && frame.interaction.cursor.is_some() {
                request_pick(frame.interaction, PickRequest::NodeSelect);
            }
        }
    }

    if session.node_dragging() {
        if clicks.is_left_down {
            if let Some(coord) = frame.coord {
                session.update_node_drag(coord);
            }
        } else {
            session.finish_node_drag(frame.is_hovered && frame.coord.is_some());
        }
    }
}

impl UiState {
    #[allow(clippy::too_many_arguments)]
    pub(super) fn draw_tool_gizmo(
        &mut self, ui: &Ui, session: &mut Session, settings: &Settings, frame: &mut ViewFrame<'_>, tool: Tool,
        gizmo_view: GizmoMapView,
    ) -> bool {
        match tool {
            Tool::Pick => {
                self.gizmo
                    .draw(
                        ui,
                        session,
                        settings,
                        frame.camera,
                        self.inspector.transform_mode(),
                        gizmo_view,
                    )
                    .captures_mouse
            },
            Tool::Place => {
                self.gizmo
                    .draw_placement_direction(ui, session, settings, frame.camera, frame.coord, gizmo_view)
                    .captures_mouse
            },
            Tool::Select => self.draw_region_gizmo(ui, session, frame, gizmo_view),
            Tool::Node | Tool::Comment | Tool::Delete | Tool::Replace | Tool::Fill | Tool::RectFill | Tool::Move => {
                self.gizmo.cancel();

                false
            },
        }
    }

    pub(super) fn end_strokes(&mut self, session: &Session, clicks: Clicks, is_gizmo_capturing: bool) {
        if clicks.is_left_clicked {
            self.placement_stroke = None;
            self.pick_stroke = None;
        }

        if !clicks.is_left_down || !matches!(session.tool(), Tool::Delete | Tool::Replace) {
            self.pick_stroke = None;
        }

        if self.placement_stroke.as_ref().is_some_and(|stroke| {
            !clicks.is_left_down
                || is_gizmo_capturing
                || !stroke.matches_context(session.tool(), session.palette(), session.z())
        }) {
            self.placement_stroke = None;
        }
    }

    pub(super) fn apply_tool_at(
        &mut self, ui: &Ui, session: &mut Session, settings: &Settings, frame: &mut ViewFrame<'_>, cursor: [f32; 2],
        clicks: Clicks,
    ) {
        let pixel = [cursor[0].floor() as u32, cursor[1].floor() as u32];
        frame.interaction.cursor = Some(cursor_in_map_view(cursor, frame.layout.scale));
        let is_alternate = settings.keybindings.get(KeybindAction::ToolAlternate).is_held(ui);

        let Some(coord) = frame.coord else {
            return;
        };

        let tool = session.tool();
        if !matches!(tool, Tool::Place | Tool::Node) {
            self.placement_stroke = None;
        }

        match tool {
            Tool::Place => self.place_at(ui, session, settings, frame, coord, clicks, is_alternate),
            Tool::Pick => {
                if clicks.is_left_double_clicked {
                    request_pick(frame.interaction, PickRequest::NodeSeed(coord));
                } else if clicks.is_left_clicked {
                    request_pick(frame.interaction, PickRequest::Pick);
                }
            },
            Tool::Node => {},
            Tool::Comment => {
                if clicks.is_left_clicked && session.coop_shared_map_path(frame.id).is_some() {
                    self.comment_draft = Some(CommentDraft::new(frame.id, frame.camera.screen_to_map(cursor)));
                    ui.open_popup(COMMENT_POPUP);
                }
            },
            Tool::Select => self.start_rectangle(ui, session, frame, coord, clicks.is_left_clicked),
            Tool::Delete | Tool::Replace => self.pick_at(ui, session, frame, coord, pixel, clicks, is_alternate),
            Tool::Fill => self.fill_at(ui, session, coord, clicks.is_left_clicked),
            Tool::RectFill => self.start_fill_rect(session, frame, coord, clicks.is_left_clicked),
            Tool::Move => self.move_at(ui, session, frame, clicks),
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn place_at(
        &mut self, ui: &Ui, session: &mut Session, settings: &Settings, frame: &mut ViewFrame<'_>, coord: Coord,
        clicks: Clicks, is_alternate: bool,
    ) {
        if clicks.is_left_clicked {
            self.placement_stroke = session
                .palette()
                .cloned()
                .map(|prefab| PlacementStroke::new(prefab, session.z()));
        }

        let group = session
            .can_edit_at(coord)
            .then(|| self.placement_stroke.as_mut().and_then(|stroke| stroke.visit(coord)))
            .flatten();
        let placed = group.and_then(|group| {
            if is_alternate {
                session.place_replacing_objs_at(coord, Some(group))
            } else {
                session.place_at(coord, Some(group))
            }
        });
        if settings.tile_place_flash
            && let Some(owner) = placed
        {
            let flash = ActivePlacementFlash {
                owner,
                coord,
                started_at: ui.time(),
            };
            self.placement_flash = Some(flash);
            frame.interaction.placement_flash = flash.sample(ui.time());
        }
    }

    #[allow(clippy::too_many_arguments)]
    fn pick_at(
        &mut self, ui: &Ui, session: &mut Session, frame: &mut ViewFrame<'_>, coord: Coord, pixel: [u32; 2],
        clicks: Clicks, is_alternate: bool,
    ) {
        let tool = session.tool();
        if tool == Tool::Replace && session.palette().is_none() {
            ui.tooltip_text("Choose a brush to replace atoms with");
        }

        if clicks.is_left_clicked {
            self.pick_stroke = Some(PickStroke::new(pixel, session.z()));
        }

        if tool == Tool::Delete && is_alternate {
            frame.interaction.cursor = None;
            if let Some(group) = self.pick_stroke.as_mut().and_then(|stroke| stroke.clear(coord)) {
                session.delete_tile(coord, Some(group));
            }
        } else if clicks.is_left_clicked
            || (clicks.is_left_down && self.pick_stroke.as_mut().is_some_and(|stroke| stroke.move_to(pixel)))
        {
            let request = match tool {
                Tool::Delete => PickRequest::Delete,
                _ => PickRequest::Replace,
            };
            request_pick(frame.interaction, request);
        }
    }

    fn fill_at(&mut self, ui: &Ui, session: &mut Session, coord: Coord, is_left_clicked: bool) {
        if session.selection_mask().is_some_and(|mask| !mask.includes(coord)) {
            ui.tooltip_text("Click a selected tile, or press Escape to clear the selection");
        }

        if is_left_clicked
            && let FillOutcome::TooLarge { limit } =
                session.fill_at(coord, self.fill_mode, &self.custom_fill_boundaries)
        {
            self.pending_fill_warning = Some(PendingFillWarning {
                context: FillWarningContext::capture(session),
                coord,
                fill_mode: self.fill_mode,
                custom_fill_boundaries: self.custom_fill_boundaries.clone(),
                limit,
            });
            ui.open_popup(FILL_LIMIT_WARNING_POPUP);
        }
    }

    fn move_at(&mut self, ui: &Ui, session: &mut Session, frame: &mut ViewFrame<'_>, clicks: Clicks) {
        if clicks.is_left_clicked {
            self.move_drag = None;
            request_pick(frame.interaction, PickRequest::Move);
        }

        if !clicks.is_left_down {
            self.move_drag = None;
            return;
        }

        if let Some(drag) = self.move_drag.as_ref()
            && (drag.document != frame.id || drag.z != session.z() || session.picked_instance() != Some(drag.picked))
        {
            self.move_drag = None;
        }

        let mode = self.inspector.transform_mode();
        let target = session
            .picked_transform()
            .filter(|target| target.sprite.z == session.z());

        let Some(drag) = self.move_drag.as_ref() else {
            let Some(target) = target else {
                return;
            };
            let Some(values) = transform_values(target, mode) else {
                return;
            };
            let Some(location) = session.picked_location() else {
                return;
            };

            self.move_drag = Some(MoveDrag {
                document: frame.id,
                z: session.z(),
                picked: target.picked,
                start_mouse: ui.io().mouse_pos(),
                start_anchor: [target.sprite.x, target.sprite.y],
                start_values: values,
                start_coord: location.coord,
                zoom: frame.camera.camera.zoom.max(f32::EPSILON),
                tile_size: session.options.tile_size.max(1),
                group: EditGroupId::new(),
            });

            return;
        };

        let Some(target) = target else {
            return;
        };
        drive_move_drag(ui, session, drag, target, mode);
    }
}

#[derive(Debug, Clone, Copy)]
pub(in crate::ui) struct MoveDrag {
    pub(in crate::ui) document: DocumentId,
    z: u32,
    picked: PrefabInstanceId,
    start_mouse: [f32; 2],
    start_anchor: [f32; 2],
    start_values: [i32; 2],
    start_coord: Coord,
    zoom: f32,
    tile_size: u32,
    group: EditGroupId,
}

struct DraggedMove {
    values: [i32; 2],
    anchor: [f32; 2],
}

fn dragged_move(drag: &MoveDrag, mouse: [f32; 2]) -> DraggedMove {
    let map_delta = [
        (mouse[0] - drag.start_mouse[0]) / drag.zoom,
        -(mouse[1] - drag.start_mouse[1]) / drag.zoom,
    ];
    let tile = drag.tile_size as f32;
    let mut anchor = drag.start_anchor;
    let mut values = drag.start_values;

    for axis in 0..2 {
        let tiles = rounded_i32(map_delta[axis] / tile);
        anchor[axis] += tiles as f32 * tile;
        values[axis] = drag.start_values[axis].saturating_add(tiles.saturating_mul(drag.tile_size as i32));
    }

    DraggedMove { values, anchor }
}

fn rounded_i32(value: f32) -> i32 {
    if value.is_finite() { value.round() as i32 } else { 0 }
}

fn drive_move_drag(ui: &Ui, session: &mut Session, drag: &MoveDrag, target: PickedTransform, mode: TransformMode) {
    let mouse = ui.io().mouse_pos();
    if !mouse.iter().all(|value| value.is_finite()) {
        return;
    }

    let Some(location) = session.picked_location() else {
        return;
    };
    let size = session
        .map()
        .map_or((1, 1), |map| (map.size().x.max(1), map.size().y.max(1)));
    let dragged = dragged_move(drag, mouse);
    let anchored = anchor_to_tile(dragged.anchor, drag.start_coord, drag.tile_size, size);
    let next = [
        dragged.values[0].saturating_add(anchored.adjust[0]),
        dragged.values[1].saturating_add(anchored.adjust[1]),
    ];
    let current = transform_values(target, mode).unwrap_or(drag.start_values);
    let mutations = transform_mutations(mode, current, next);

    if anchored.coord != location.coord {
        session.move_picked_instance(anchored.coord, "move atom", &mutations, Some(drag.group));
    } else if !mutations.is_empty() {
        session.edit_picked_instance_vars("move atom", &mutations, Some(drag.group));
    }
}
