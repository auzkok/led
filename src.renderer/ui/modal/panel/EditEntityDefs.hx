package ui.modal.panel;

class EditEntityDefs extends ui.modal.Panel {
	static var LAST_ENTITY_ID = -1;
	static var LAST_FIELD_ID = -1;

	var jEntityList(get,never) : js.jquery.JQuery; inline function get_jEntityList() return jContent.find(".entityList ul");
	var jFieldList(get,never) : js.jquery.JQuery; inline function get_jFieldList() return jContent.find(".fieldList ul");

	var jEntityForm(get,never) : js.jquery.JQuery; inline function get_jEntityForm() return jContent.find(".entityForm>ul.form");
	var jFieldForm(get,never) : js.jquery.JQuery; inline function get_jFieldForm() return jContent.find(".fieldForm>ul.form");
	var jPreview(get,never) : js.jquery.JQuery; inline function get_jPreview() return jContent.find(".previewWrapper");

	var curEntity : Null<led.def.EntityDef>;
	var curField : Null<led.def.FieldDef>;

	public function new() {
		super();

		loadTemplate( "editEntityDefs", "defEditor entityDefs" );
		linkToButton("button.editEntities");

		// Create entity
		jEntityList.parent().find("button.create").click( function(_) {
			var ed = project.defs.createEntityDef();
			selectEntity(ed);
			editor.ge.emit(EntityDefAdded);
			jEntityForm.find("input").first().focus().select();
		});

		// Delete entity
		jEntityList.parent().find("button.delete").click( function(ev) {
			if( curEntity==null ) {
				N.error("No entity selected.");
				return;
			}
			var isUsed = project.isEntityDefUsed(curEntity);
			new ui.modal.dialog.Confirm(
				ev.getThis(),
				isUsed
					? Lang.t._("WARNING! This entity is used in one more levels. They will also be removed!")
					: Lang.t._("This entity is not used and can be safely removed."),
				isUsed,
				function() {
					new ui.LastChance( L.t._("Entity ::name:: deleted", { name:curEntity.identifier }), project );
					project.defs.removeEntityDef(curEntity);
					editor.ge.emit(EntityDefRemoved);
					if( project.defs.entities.length>0 )
						selectEntity(project.defs.entities[0]);
					else
						selectEntity(null);
				}
			);
		});


		function createField(anchor:js.jquery.JQuery, isArray:Bool) {
			function _create(type:led.LedTypes.FieldType) {
				switch type {
					case F_Enum(null):
						// Enum picker
						var w = new ui.modal.Dialog(anchor, "enums");
						if( project.defs.enums.length==0 && project.defs.externalEnums.length==0 ) {
							w.jContent.append('<div class="warning">This project has no Enum: add one from the Enum panel.</div>');
						}

						for(ed in project.defs.enums) {
							var b = new J("<button/>");
							b.appendTo(w.jContent);
							b.text(ed.identifier);
							b.click( function(_) {
								_create(F_Enum(ed.uid));
								w.close();
							});
						}

						for(ed in project.defs.externalEnums) {
							var b = new J("<button/>");
							b.appendTo(w.jContent);
							b.append('<span class="id">${ed.identifier}</span>');

							var fileName = dn.FilePath.extractFileWithExt(ed.externalRelPath);
							b.append('<span class="source">$fileName</span>');

							b.click( function(_) {
								_create(F_Enum(ed.uid));
								w.close();
							});
						}
						return;


					case _:
				}
				var f = curEntity.createFieldDef(project, type);
				f.isArray = isArray;
				editor.ge.emit( EntityFieldAdded(curEntity) );
				selectField(f);
				jFieldForm.find("input:not([readonly]):first").focus().select();
			}

			// Type picker
			var w = new ui.modal.Dialog(anchor,"fieldTypes");
			var types : Array<led.LedTypes.FieldType> = [
				F_Int, F_Float, F_Bool, F_String, F_Enum(null), F_Color, F_Point
			];
			for(type in types) {
				var b = new J("<button/>");
				w.jContent.append(b);
				JsTools.createFieldTypeIcon(type, b);
				b.click( function(ev) {
					_create(type);
					w.close();
				});
			}
		}

		// Create single field
		jFieldList.parent().find("button.createSingle").click( function(ev) {
			createField(ev.getThis(), false);
		});

		// Create single field
		jFieldList.parent().find("button.createArray").click( function(ev) {
			createField(ev.getThis(), true);
		});

		// Delete field
		jFieldList.parent().find("button.delete").click( function(ev) {
			if( curField==null ) {
				N.error("No field selected.");
				return;
			}

			new ui.modal.dialog.Confirm(
				ev.getThis(),
				true,
				function() {
					new ui.LastChance( L.t._("Entity field ::name:: deleted", { name:curField.identifier }), project );
					curEntity.removeField(project, curField);
					editor.ge.emit( EntityFieldRemoved(curEntity) );
					selectField( curEntity.fieldDefs[0] );
				}
			);
		});

		// Select same entity as current client selection
		var lastFieldId = LAST_FIELD_ID; // because selectEntity changes it
		if( editor.curLayerDef!=null && editor.curLayerDef.type==Entities )
			selectEntity( project.defs.getEntityDef(editor.curTool.getSelectedValue()) );
		else if( LAST_ENTITY_ID>=0 && project.defs.getEntityDef(LAST_ENTITY_ID)!=null )
			selectEntity( project.defs.getEntityDef(LAST_ENTITY_ID) );
		else
			selectEntity(project.defs.entities[0]);

		// Re-select last field
		if( lastFieldId>=0 && curEntity!=null && curEntity.getFieldDef(lastFieldId)!=null )
			selectField( curEntity.getFieldDef(lastFieldId) );
	}

	override function onGlobalEvent(e:GlobalEvent) {
		super.onGlobalEvent(e);
		switch e {
			case ProjectSettingsChanged, ProjectSelected, LevelSettingsChanged, LevelSelected:
				close();

			case LayerInstanceRestoredFromHistory(li):
				updatePreview();
				updateEntityForm();
				updateFieldForm();
				updateLists();

			case EntityDefChanged, EntityDefAdded, EntityDefRemoved:
				updatePreview();
				updateEntityForm();
				updateFieldForm();
				updateLists();

			case EntityDefSorted, EntityFieldSorted:
				updateLists();

			case EntityFieldAdded(ed), EntityFieldRemoved(ed), EntityFieldDefChanged(ed):
				updateLists();
				updateFieldForm();

			case _:
		}
	}

	function selectEntity(ed:Null<led.def.EntityDef>) {
		if( ed==null )
			ed = editor.project.defs.entities[0];

		curEntity = ed;
		curField = ed==null ? null : ed.fieldDefs[0];
		LAST_ENTITY_ID = curEntity==null ? -1 : curEntity.uid;
		LAST_FIELD_ID = curField==null ? -1 : curField.uid;
		updatePreview();
		updateEntityForm();
		updateFieldForm();
		updateLists();
	}

	function selectField(fd:led.def.FieldDef) {
		curField = fd;
		LAST_FIELD_ID = curField==null ? -1 : curField.uid;
		updateFieldForm();
		updateLists();
	}


	function updateEntityForm() {
		jEntityForm.find("*").off(); // cleanup event listeners

		var jAll = jEntityForm.add( jFieldForm ).add( jFieldList.parent() ).add( jPreview );
		if( curEntity==null ) {
			jAll.css("visibility","hidden");
			jContent.find(".none").show();
			jContent.find(".noEntLayer").hide();
			return;
		}

		JsTools.parseComponents(jEntityForm);
		jAll.css("visibility","visible");
		jContent.find(".none").hide();
		if( !project.defs.hasLayerType(Entities) )
			jContent.find(".noEntLayer").show();
		else
			jContent.find(".noEntLayer").hide();


		// Name
		var i = Input.linkToHtmlInput(curEntity.identifier, jEntityForm.find("input[name='name']") );
		i.validityCheck = function(id) return led.Project.isValidIdentifier(id) && project.defs.isEntityIdentifierUnique(id);
		i.validityError = N.invalidIdentifier;
		i.linkEvent(EntityDefChanged);

		// Dimensions
		var i = Input.linkToHtmlInput( curEntity.width, jEntityForm.find("input[name='width']") );
		i.setBounds(1,256);
		i.onChange = editor.ge.emit.bind(EntityDefChanged);

		var i = Input.linkToHtmlInput( curEntity.height, jEntityForm.find("input[name='height']") );
		i.setBounds(1,256);
		i.onChange = editor.ge.emit.bind(EntityDefChanged);

		// Display renderMode form fields based on current mode
		var jRenderModeBlock = jEntityForm.find("li.renderMode");
		JsTools.removeClassReg(jRenderModeBlock, ~/mode_\S+/g);
		jRenderModeBlock.find("canvas").remove();
		jRenderModeBlock.addClass("mode_"+curEntity.renderMode);

		// Color
		var col = jEntityForm.find("input[name=color]");
		col.val( C.intToHex(curEntity.color) );
		col.change( function(ev) {
			curEntity.color = C.hexToInt( col.val() );
			editor.ge.emit(EntityDefChanged);
			updateEntityForm();
		});

		// Render mode
		var i = new form.input.EnumSelect(
			jEntityForm.find("select.renderMode"),
			led.LedTypes.EntityRenderMode,
			function() return curEntity.renderMode,
			function(v) {
				curEntity.tileId = null;
				curEntity.tilesetId = null;
				curEntity.renderMode = v;
			}
		);
		i.linkEvent(EntityDefChanged);

		// Tileset pick
		var jTilesets = jEntityForm.find("select.tilesets");
		jTilesets.find("option:not(:first)").remove();
		if( curEntity.renderMode==Tile ) {
			for( td in project.defs.tilesets ) {
				var opt = new J('<option/>');
				opt.appendTo(jTilesets);
				opt.attr("value",td.uid);
				opt.text( td.identifier );
				if( td.uid==curEntity.tilesetId )
					opt.attr("selected","selected");
			}
			jTilesets.change( function(_) {
				var id = Std.parseInt( jTilesets.val() );
				curEntity.tileId = null;
				if( !M.isValidNumber(id) || id<0 )
					curEntity.tilesetId = null;
				else
					curEntity.tilesetId = id;
				editor.ge.emit(EntityDefChanged);
			});
		}

		// Tile pick
		if( curEntity.renderMode==Tile ) {
			var jPicker = JsTools.createTilePicker(curEntity.tilesetId, true, [curEntity.tileId], function(tileIds) {
				curEntity.tileId = tileIds[0];
				editor.ge.emit(EntityDefChanged);
			});
			jRenderModeBlock.append(jPicker);
		}


		// Max per level
		var i = Input.linkToHtmlInput(curEntity.maxPerLevel, jEntityForm.find("input[name='maxPerLevel']") );
		i.setBounds(0,1024);
		i.onChange = editor.ge.emit.bind(EntityDefChanged);

		// Behavior when max is reached
		var i = new form.input.EnumSelect(
			jEntityForm.find("select[name=limitBehavior]"),
			led.LedTypes.EntityLimitBehavior,
			function() return curEntity.limitBehavior,
			function(v) {
				curEntity.limitBehavior = v;
			},
			function(k) {
				return Lang.untranslated("... ") + switch k {
					case DiscardOldOnes: Lang.t._("discard older ones");
					case PreventAdding: Lang.t._("prevent adding more");
					case MoveLastOne: Lang.t._("move the last one instead of adding");
				}
			}
		);

		// Pivot
		var jPivots = jEntityForm.find(".pivot");
		jPivots.empty();
		var p = JsTools.createPivotEditor(curEntity.pivotX, curEntity.pivotY, curEntity.color, function(x,y) {
			curEntity.pivotX = x;
			curEntity.pivotY = y;
			editor.ge.emit(EntityDefChanged);
		});
		jPivots.append(p);
	}


	function updateFieldForm() {
		jFieldForm.find("*").off(); // cleanup events

		if( curField==null ) {
			jFieldForm.css("visibility","hidden");
			return;
		}
		else
			jFieldForm.css("visibility","visible");

		JsTools.parseComponents(jFieldForm);

		// Set form classes
		for(k in Type.getEnumConstructs(led.LedTypes.FieldType))
			jFieldForm.removeClass("type-"+k);
		jFieldForm.addClass("type-"+curField.type.getName());

		if( curField.isArray )
			jFieldForm.addClass("type-Array");
		else
			jFieldForm.removeClass("type-Array");

		// Type desc
		jFieldForm.find(".type").val( curField.getShortDescription() );


		var i = new form.input.EnumSelect(
			jFieldForm.find("select[name=editorDisplayMode]"),
			led.LedTypes.FieldDisplayMode,
			function() return curField.editorDisplayMode,
			function(v) return curField.editorDisplayMode = v
		);
		i.linkEvent( EntityFieldDefChanged(curEntity) );

		var i = new form.input.EnumSelect(
			jFieldForm.find("select[name=editorDisplayPos]"),
			led.LedTypes.FieldDisplayPosition,
			function() return curField.editorDisplayPos,
			function(v) return curField.editorDisplayPos = v
		);
		i.setEnabled( curField.editorDisplayMode!=Hidden );
		i.linkEvent( EntityFieldDefChanged(curEntity) );

		var i = Input.linkToHtmlInput( curField.identifier, jFieldForm.find("input[name=name]") );
		i.linkEvent( EntityFieldDefChanged(curEntity) );
		i.validityCheck = function(id) {
			return led.Project.isValidIdentifier(id) && curEntity.isFieldIdentifierUnique(id);
		}
		i.validityError = N.invalidIdentifier;

		// Default value
		switch curField.type {
			case F_Int, F_Float, F_String, F_Point:
				var defInput = jFieldForm.find("input[name=fDef]");
				if( curField.defaultOverride != null )
					defInput.val( Std.string( curField.getUntypedDefault() ) );
				else
					defInput.val("");

				if( curField.type==F_String && !curField.canBeNull )
					defInput.attr("placeholder", "(empty string)");
				else if( curField.canBeNull )
					defInput.attr("placeholder", "(null)");
				else
					defInput.attr("placeholder", switch curField.type {
						case F_Int: Std.string( curField.iClamp(0) );
						case F_Float: Std.string( curField.fClamp(0) );
						case F_String: "";
						case F_Point: "0"+Const.POINT_SEPARATOR+"0";
						case F_Bool, F_Color, F_Enum(_): "N/A";
					});

				defInput.change( function(ev) {
					curField.setDefault( defInput.val() );
					editor.ge.emit( EntityFieldDefChanged(curEntity) );
					defInput.val( curField.defaultOverride==null ? "" : Std.string(curField.getUntypedDefault()) );
				});

			case F_Enum(name):
				var ed = project.defs.getEnumDef(name);
				var enumDef = jFieldForm.find("[name=enumDef]");
				enumDef.find("[value]").remove();
				if( curField.canBeNull ) {
					var opt = new J('<option/>');
					opt.appendTo(enumDef);
					opt.attr("value","");
					opt.text("-- null --");
					if( curField.getEnumDefault()==null )
						opt.attr("selected","selected");
				}
				for(v in ed.values) {
					var opt = new J('<option/>');
					opt.appendTo(enumDef);
					opt.attr("value",v.id);
					opt.text(v.id);
					if( curField.getEnumDefault()==v.id )
						opt.attr("selected","selected");
				}

				enumDef.change( function(ev) {
					var v = enumDef.val();
					if( v=="" && curField.canBeNull )
						curField.setDefault(null);
					else if( v!="" )
						curField.setDefault(v);
					editor.ge.emit( EntityFieldDefChanged(curEntity) );
				});

			case F_Color:
				var defInput = jFieldForm.find("input[name=cDef]");
				defInput.val( C.intToHex(curField.getColorDefault()) );
				defInput.change( function(ev) {
					curField.setDefault( defInput.val() );
					editor.ge.emit( EntityFieldDefChanged(curEntity) );
				});

			case F_Bool:
				var defInput = jFieldForm.find("input[name=bDef]");
				defInput.prop("checked", curField.getBoolDefault());
				defInput.change( function(ev) {
					var checked = defInput.prop("checked") == true;
					curField.setDefault( Std.string(checked) );
					editor.ge.emit( EntityFieldDefChanged(curEntity) );
				});
		}

		// Nullable
		var i = Input.linkToHtmlInput( curField.canBeNull, jFieldForm.find("input[name=canBeNull]") );
		i.onChange = editor.ge.emit.bind( EntityFieldDefChanged(curEntity) );

		// Array size constraints
		if( curField.isArray ) {
			// Min
			var i = new form.input.IntInput(
				jFieldForm.find("input[name=arrayMinLength]"),
				function() return curField.arrayMinLength,
				function(v) {
					curField.arrayMinLength = v<=0 ? null : v;
					if( curField.arrayMinLength!=null && curField.arrayMaxLength!=null )
						curField.arrayMaxLength = M.imax( curField.arrayMaxLength, curField.arrayMinLength );
				}
			);
			i.setBounds(0, 99999);
			i.linkEvent( EntityFieldDefChanged(curEntity) );
			// Max
			var i = new form.input.IntInput(
				jFieldForm.find("input[name=arrayMaxLength]"),
				function() return curField.arrayMaxLength,
				function(v) {
					curField.arrayMaxLength = v<=0 ? null : v;
					if( curField.arrayMinLength!=null && curField.arrayMaxLength!=null )
						curField.arrayMinLength = M.imin( curField.arrayMaxLength, curField.arrayMinLength );
				}
			);
			i.setBounds(0, 99999);
			i.linkEvent( EntityFieldDefChanged(curEntity) );
			// Max
			// var i = new form.input.IntInput(
			// 	jFieldForm.find("input[name=arrayMinLength]"),
			// 	function() return curField.arrayMinLength,
			// 	function(v) curField.arrayMinLength = v
			// );
		}
		// var i = Input.linkToHtmlInput( curField.arrayMinLength, jFieldForm.find("input[name=arrayMinLength]") );
		// i.onChange = editor.ge.emit.bind( EntityFieldDefChanged(curEntity) );

		// Min
		var input = jFieldForm.find("input[name=min]");
		input.val( curField.min==null ? "" : curField.min );
		input.change( function(ev) {
			curField.setMin( input.val() );
			editor.ge.emit( EntityFieldDefChanged(curEntity) );
		});

		// Max
		var input = jFieldForm.find("input[name=max]");
		input.val( curField.max==null ? "" : curField.max );
		input.change( function(ev) {
			curField.setMax( input.val() );
			editor.ge.emit( EntityFieldDefChanged(curEntity) );
		});
	}


	function updateLists() {
		jEntityList.empty();
		jFieldList.empty();

		// Entities
		for(ed in project.defs.entities) {
			var elem = new J("<li/>");
			jEntityList.append(elem);
			elem.addClass("iconLeft");

			var preview = JsTools.createEntityPreview(editor.project, ed);
			preview.appendTo(elem);

			elem.append('<span class="name">'+ed.identifier+'</span>');
			if( curEntity==ed ) {
				elem.addClass("active");
				elem.css( "background-color", C.intToHex( C.toWhite(ed.color, 0.5) ) );
			}
			else
				elem.css( "color", C.intToHex( C.toWhite(ed.color, 0.5) ) );

			elem.click( function(_) selectEntity(ed) );
		}

		// Make list sortable
		JsTools.makeSortable(jEntityList, function(ev) {
			var moved = project.defs.sortEntityDef(ev.oldIndex, ev.newIndex);
			selectEntity(moved);
			editor.ge.emit(EntityDefSorted);
		});

		// Fields
		if( curEntity!=null ) {
			for(f in curEntity.fieldDefs) {
				var li = new J("<li/>");
				li.appendTo(jFieldList);
				li.append('<span class="name">'+f.identifier+'</span>');
				if( curField==f )
					li.addClass("active");

				var sub = new J('<span class="sub"></span>');
				sub.appendTo(li);
				sub.text( f.getShortDescription() );

				li.click( function(_) selectField(f) );
			}
		}

		// Make fields list sortable
		JsTools.makeSortable(jFieldList, function(ev) {
			var moved = curEntity.sortField(ev.oldIndex, ev.newIndex);
			selectField(moved);
			editor.ge.emit( EntityFieldSorted );
		});
	}


	function updatePreview() {
		if( curEntity==null )
			return;

		jPreview.children(".entityPreview").remove();
		jPreview.append( JsTools.createEntityPreview(project, curEntity, 64) );
	}
}
