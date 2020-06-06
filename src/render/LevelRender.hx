package render;

class LevelRender extends dn.Process {
	public var client(get,never) : Client; inline function get_client() return Client.ME;

	var layerVis : Map<Int,Bool> = new Map();
	var layerWrappers : Map<Int,h2d.Object> = new Map();
	var invalidated = true;

	var grid : h2d.Graphics;

	public var focusX : Float = 0.;
	public var focusY : Float = 0.;
	public var zoom : Float = 3.0;

	public function new() {
		super(client);

		client.ge.watchAny(onGlobalEvent);

		createRootInLayers(client.root, Const.DP_MAIN);

		grid = new h2d.Graphics();
		root.add(grid, 0);
	}

	override function onDispose() {
		super.onDispose();
		client.ge.remove(onGlobalEvent);
	}

	function onGlobalEvent(e:GlobalEvent) {
		invalidate();
	}

	public inline function isLayerVisible(l:LayerContent) {
		return !layerVis.exists(l.layerDefId) || layerVis.get(l.layerDefId)==true;
	}

	public function toggleLayer(l:LayerContent) {
		layerVis.set(l.layerDefId, !isLayerVisible(l));
		updateLayersVisibility();
	}

	public function showLayer(l:LayerContent) {
		layerVis.set(l.layerDefId, true);
		invalidate();
	}

	public function hideLayer(l:LayerContent) {
		layerVis.set(l.layerDefId, false);
		invalidate();
	}

	public function renderGrid() {
		var l = client.curLayerContent;
		grid.clear();
		grid.lineStyle(1, 0x0, 0.2);
		for( cx in 0...client.curLayerContent.cWid+1 ) {
			grid.moveTo(cx*l.def.gridSize, 0);
			grid.lineTo(cx*l.def.gridSize, l.cHei*l.def.gridSize);
		}
		for( cy in 0...client.curLayerContent.cHei+1 ) {
			grid.moveTo(0, cy*l.def.gridSize);
			grid.lineTo(l.cWid*l.def.gridSize, cy*l.def.gridSize);
		}
	}

	public function renderAll() {
		renderGrid();
		renderLayers();
	}

	public function renderLayers() {
		for(e in layerWrappers)
			e.remove();
		layerWrappers = new Map();

		for(lc in client.curLevel.layerContents) {
			var wrapper = new h2d.Object();
			root.add(wrapper,1);
			root.under(wrapper);
			layerWrappers.set(lc.layerDefId, wrapper);

			if( !isLayerVisible(lc) )
				continue;

			var grid = lc.def.gridSize;
			switch lc.def.type {
				case IntGrid:
					var g = new h2d.Graphics(wrapper);
					for(cy in 0...lc.cHei)
					for(cx in 0...lc.cWid) {
						var id = lc.getIntGrid(cx,cy);
						if( id<0 )
							continue;

						g.beginFill( lc.getIntGridColorAt(cx,cy) );
						g.drawRect(cx*grid, cy*grid, grid, grid);
					}

				case Entities:
					for(ei in lc.entityInstances) {
						var o = EntityInstance.createRender(ei.def, wrapper);
						o.setPosition(ei.x, ei.y);
					}
			}
		}

		updateLayersVisibility();
	}

	function updateLayersVisibility() {
		for(lid in layerWrappers.keys()) {
			var lc = client.curLevel.getLayerContent(lid);
			var wrapper = layerWrappers.get(lid);
			wrapper.visible = isLayerVisible(lc);
			wrapper.alpha = lc.def.displayOpacity;
			// wrapper.alpha = lc.def.displayOpacity * ( lc==client.curLayerContent ? 1 : 0.25 );
		}
	}

	public function onCurrentLayerChange(cur:LayerContent) {
		updateLayersVisibility();
		renderGrid();
	}


	public inline function invalidate() {
		invalidated = true;
	}

	override function postUpdate() {
		super.postUpdate();

		root.setScale(zoom);
		// root.x = w()*0.5 - focusX * zoom;
		// root.y = h()*0.5 - focusY * zoom;

		if( invalidated ) {
			invalidated = false;
			renderAll();
		}
	}

}
