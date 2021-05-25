package;

import flixel.addons.ui.FlxUIText;
import haxe.zip.Writer;
import Conductor.BPMChangeEvent;
import Section.SwagSection;
import Song.SwagSong;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxInputText;
import flixel.addons.ui.FlxUI9SliceSprite;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUITabMenu;
import flixel.addons.ui.FlxUITooltip.FlxUITooltipStyle;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.system.FlxSound;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.ui.FlxSpriteButton;
import flixel.util.FlxColor;
import haxe.Json;
import lime.utils.Assets;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.events.IOErrorEvent;
import openfl.events.IOErrorEvent;
import openfl.media.Sound;
import openfl.net.FileReference;
import openfl.utils.ByteArray;
import flixel.FlxGame;
import flixel.tweens.motion.QuadMotion;
import flixel.tweens.misc.AngleTween;
import flixel.ui.FlxVirtualPack;
import haxepunk.Screen;
import haxepunk.screen.FixedScaleMode;
import haxepunk.cameras.StaticCamera;

using StringTools;

class ChartingState extends MusicBeatState
{
	var _file:FileReference;

	var UI_box:FlxUITabMenu;

	/**
	 * Array of notes showing when each section STARTS in STEPS
	 * Usually rounded up??
	 */
	var curSection:Int = 0;

	public static var lastSection:Int = 0;

	var bpmTxt:FlxText;

	var strumLine:FlxSprite;
	var curSong:String = 'Dad Battle';
	var amountSteps:Int = 0;
	var bullshitUI:FlxGroup;
	var writingNotesText:FlxText;
	var highlight:FlxSprite;

	var GRID_SIZE:Int = 40;

	var dummyArrow:FlxSprite;

	var curRenderedNotes:FlxTypedGroup<Note>;
	var curRenderedSustains:FlxTypedGroup<FlxSprite>;

	var gridBG:FlxSprite;

	var _song:SwagSong;

	var typingShit:FlxInputText;
	/*
	 * WILL BE THE CURRENT / LAST PLACED NOTE
	**/
	var curSelectedNote:Array<Dynamic>;

	var tempBpm:Int = 0;
	var gridBlackLine:FlxSprite;
	var vocals:FlxSound;

	var player2:Character = new Character(0,0, "dad");
	var player1:Boyfriend = new Boyfriend(0,0, "bf");

	var leftIcon:HealthIcon;
	var rightIcon:HealthIcon;

	private var lastNote:Note;
	var claps:Array<Note> = [];

	override function create()
	{
		curSection = lastSection;

		if (PlayState.SONG != null)
			_song = PlayState.SONG;
		else
		{
			_song = {
				song: 'Test',
				notes: [],
				bpm: 150,
				needsVoices: true,
				player1: 'bf',
				player2: 'dad',
				gfVersion: 'gf',
				noteStyle: 'normal',
				stage: 'stage',
				speed: 1,
				validScore: false
			};
		}

		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 8, GRID_SIZE * 16);
		add(gridBG);

		gridBlackLine = new FlxSprite(gridBG.x + gridBG.width / 2).makeGraphic(2, Std.int(gridBG.height), FlxColor.BLACK);
		add(gridBlackLine);

		curRenderedNotes = new FlxTypedGroup<Note>();
		curRenderedSustains = new FlxTypedGroup<FlxSprite>();

		FlxG.mouse.visible = true;
		FlxG.save.bind('funkin', 'ninjamuffin99');

		tempBpm = _song.bpm;

		addSection();

		// sections = _song.notes;

		updateGrid();

		loadSong(_song.song);
		Conductor.changeBPM(_song.bpm);
		Conductor.mapBPMChanges(_song);

		leftIcon = new HealthIcon(_song.player1);
		rightIcon = new HealthIcon(_song.player2);
		leftIcon.scrollFactor.set(1, 1);
		rightIcon.scrollFactor.set(1, 1);

		leftIcon.setGraphicSize(0, 45);
		rightIcon.setGraphicSize(0, 45);

		add(leftIcon);
		add(rightIcon);

		leftIcon.setPosition(0, -100);
		rightIcon.setPosition(gridBG.width / 2, -100);

		bpmTxt = new FlxText(1000, 50, 0, "", 16);
		bpmTxt.scrollFactor.set();
		add(bpmTxt);

		strumLine = new FlxSprite(0, 50).makeGraphic(Std.int(FlxG.width / 2), 4);
		add(strumLine);

		dummyArrow = new FlxSprite().makeGraphic(GRID_SIZE, GRID_SIZE);
		add(dummyArrow);

		var tabs = [
			{name: "Song", label: 'Song Data'},
			{name: "Section", label: 'Section Data'},
			{name: "Note", label: 'Note Data'},
			{name: "Assets", label: 'Assets'}
		];

		UI_box = new FlxUITabMenu(null, tabs, true);

		UI_box.resize(300, 400);
		UI_box.x = FlxG.width / 2;
		UI_box.y = 20;
		add(UI_box);

		addSongUI();
		addSectionUI();
		addNoteUI();

		add(curRenderedNotes);
		add(curRenderedSustains);

		super.create();
	}

	function addSongUI():Void
	{
		var UI_songTitle = new FlxUIInputText(10, 10, 70, _song.song, 8);
		typingShit = UI_songTitle;

		var check_voices = new FlxUICheckBox(10, 25, null, null, "Has voice track", 100);
		check_voices.checked = _song.needsVoices;
		// _song.needsVoices = check_voices.checked;
		check_voices.callback = function()
		{
			_song.needsVoices = check_voices.checked;
			trace('CHECKED!');
		};

		var check_mute_inst = new FlxUICheckBox(10, 200, null, null, "Mute Instrumental (in editor)", 100);
		check_mute_inst.checked = false;
		check_mute_inst.callback = function()
		{
			var vol:Float = 1;

			if (check_mute_inst.checked)
				vol = 0;

			FlxG.sound.music.volume = vol;
		};

		var saveButton:FlxButton = new FlxButton(110, 8, "Save", function()
		{
			saveLevel();
		});

		var reloadSong:FlxButton = new FlxButton(saveButton.x + saveButton.width + 10, saveButton.y, "Reload Audio", function()
		{
			loadSong(_song.song);
		});

		var reloadSongJson:FlxButton = new FlxButton(reloadSong.x, saveButton.y + 30, "Reload JSON", function()
		{
			loadJson(_song.song.toLowerCase());
		});

		
		var restart = new FlxButton(10,140,"Reset Chart", function()
            {
                for (ii in 0..._song.notes.length)
                {
                    for (i in 0..._song.notes[ii].sectionNotes.length)
                        {
                            _song.notes[ii].sectionNotes = [];
                        }
                }
                resetSection(true);
            });

		var loadAutosaveBtn:FlxButton = new FlxButton(reloadSongJson.x, reloadSongJson.y + 30, 'load autosave', loadAutosave);
		var stepperBPM:FlxUINumericStepper = new FlxUINumericStepper(10, 65, 0.1, 1, 1.0, 5000.0, 1);
		stepperBPM.value = Conductor.bpm;
		stepperBPM.name = 'song_bpm';

		var stepperBPMLabel = new FlxText(74,65,'BPM');
		
		var stepperSpeed:FlxUINumericStepper = new FlxUINumericStepper(10, 80, 0.1, 1, 0.1, 10, 1);
		stepperSpeed.value = _song.speed;
		stepperSpeed.name = 'song_speed';

		var stepperSpeedLabel = new FlxText(74,80,'Scroll Speed');
		
		var stepperVocalVol:FlxUINumericStepper = new FlxUINumericStepper(10, 95, 0.1, 1, 0.1, 10, 1);
		stepperVocalVol.value = vocals.volume;
		stepperVocalVol.name = 'song_vocalvol';

		var stepperVocalVolLabel = new FlxText(74, 95, 'Vocal Volume');
		
		var stepperSongVol:FlxUINumericStepper = new FlxUINumericStepper(10, 110, 0.1, 1, 0.1, 10, 1);
		stepperSongVol.value = FlxG.sound.music.volume;
		stepperSongVol.name = 'song_instvol';

		var stepperSongVolLabel = new FlxText(74, 110, 'Instrumental Volume');

		var characters:Array<String> = CoolUtil.coolTextFile(Paths.txt('characterList'));
		var gfVersions:Array<String> = CoolUtil.coolTextFile(Paths.txt('gfVersionList'));
		var stages:Array<String> = CoolUtil.coolTextFile(Paths.txt('stageList'));
		var noteStyles:Array<String> = CoolUtil.coolTextFile(Paths.txt('noteStyleList'));

		var player1DropDown = new FlxUIDropDownMenu(10, 100, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player1 = characters[Std.parseInt(character)];
		});
		player1DropDown.selectedLabel = _song.player1;

		var player1Label = new FlxText(10,80,64,'Player 1');

		var player2DropDown = new FlxUIDropDownMenu(140, 100, FlxUIDropDownMenu.makeStrIdLabelArray(characters, true), function(character:String)
		{
			_song.player2 = characters[Std.parseInt(character)];
		});
		player2DropDown.selectedLabel = _song.player2;

		var player2Label = new FlxText(140,80,64,'Player 2');

		var gfVersionDropDown = new FlxUIDropDownMenu(10, 200, FlxUIDropDownMenu.makeStrIdLabelArray(gfVersions, true), function(gfVersion:String)
			{
				_song.gfVersion = gfVersions[Std.parseInt(gfVersion)];
			});
		gfVersionDropDown.selectedLabel = _song.gfVersion;

		var gfVersionLabel = new FlxText(10,180,64,'Girlfriend');

		var stageDropDown = new FlxUIDropDownMenu(140, 200, FlxUIDropDownMenu.makeStrIdLabelArray(stages, true), function(stage:String)
			{
				_song.stage = stages[Std.parseInt(stage)];
			});
		stageDropDown.selectedLabel = _song.stage;
		
		var stageLabel = new FlxText(140,180,64,'Stage');

		var noteStyleDropDown = new FlxUIDropDownMenu(10, 300, FlxUIDropDownMenu.makeStrIdLabelArray(noteStyles, true), function(noteStyle:String)
			{
				_song.noteStyle = noteStyles[Std.parseInt(noteStyle)];
			});
		noteStyleDropDown.selectedLabel = _song.noteStyle;

		var noteStyleLabel = new FlxText(10,280,64,'Note Skin');

		var tab_group_song = new FlxUI(null, UI_box);
		tab_group_song.name = "Song";
		tab_group_song.add(UI_songTitle);
		tab_group_song.add(restart);
		tab_group_song.add(check_voices);
		tab_group_song.add(check_mute_inst);
		tab_group_song.add(saveButton);
		tab_group_song.add(reloadSong);
		tab_group_song.add(reloadSongJson);
		tab_group_song.add(loadAutosaveBtn);
		tab_group_song.add(stepperBPM);
		tab_group_song.add(stepperBPMLabel);
		tab_group_song.add(stepperSpeed);
		tab_group_song.add(stepperSpeedLabel);
		tab_group_song.add(stepperVocalVol);
		tab_group_song.add(stepperVocalVolLabel);
		tab_group_song.add(stepperSongVol);
		tab_group_song.add(stepperSongVolLabel);
		
		var tab_group_assets = new FlxUI(null, UI_box);
		tab_group_assets.name = "Assets";
		tab_group_assets.add(noteStyleDropDown);
		tab_group_assets.add(noteStyleLabel);
		tab_group_assets.add(gfVersionDropDown);
		tab_group_assets.add(gfVersionLabel);
		tab_group_assets.add(stageDropDown);
		tab_group_assets.add(stageLabel);
		tab_group_assets.add(player1DropDown);
		tab_group_assets.add(player2DropDown);
		tab_group_assets.add(player1Label);
		tab_group_assets.add(player2Label);

		UI_box.addGroup(tab_group_song);
		UI_box.addGroup(tab_group_assets);
		UI_box.scrollFactor.set();

		FlxG.camera.follow(strumLine);
	}

	var stepperLength:FlxUINumericStepper;
	var check_mustHitSection:FlxUICheckBox;
	var check_changeBPM:FlxUICheckBox;
	var stepperSectionBPM:FlxUINumericStepper;
	var check_altAnim:FlxUICheckBox;

	function addSectionUI():Void
	{
		var tab_group_section = new FlxUI(null, UI_box);
		tab_group_section.name = 'Section';

		stepperLength = new FlxUINumericStepper(10, 10, 4, 0, 0, 999, 0);
		stepperLength.value = _song.notes[curSection].lengthInSteps;
		stepperLength.name = "section_length";

		var stepperLengthLabel = new FlxText(74,10,'Section Length (in steps)');

		stepperSectionBPM = new FlxUINumericStepper(10, 80, 1, Conductor.bpm, 0, 999, 0);
		stepperSectionBPM.value = Conductor.bpm;
		stepperSectionBPM.name = 'section_bpm';

		var stepperCopy:FlxUINumericStepper = new FlxUINumericStepper(110, 132, 1, 1, -999, 999, 0);
		var stepperCopyLabel = new FlxText(174,132,'sections back');

		var copyButton:FlxButton = new FlxButton(10, 130, "Copy last section", function()
		{
			copySection(Std.int(stepperCopy.value));
		});

		var clearSectionButton:FlxButton = new FlxButton(10, 150, "Clear Section", clearSection);

		var swapSection:FlxButton = new FlxButton(10, 170, "Swap Section", function()
		{
			for (i in 0..._song.notes[curSection].sectionNotes.length)
			{
				var note = _song.notes[curSection].sectionNotes[i];
				note[1] = (note[1] + 4) % 8;
				_song.notes[curSection].sectionNotes[i] = note;
				updateGrid();
			}
		});
		check_mustHitSection = new FlxUICheckBox(10, 30, null, null, "Camera Points to P1?", 100);
		check_mustHitSection.name = 'check_mustHit';
		check_mustHitSection.checked = true;
		// _song.needsVoices = check_mustHit.checked;

		check_altAnim = new FlxUICheckBox(10, 400, null, null, "Alternate Animation", 100);
		check_altAnim.name = 'check_altAnim';

		check_changeBPM = new FlxUICheckBox(10, 60, null, null, 'Change BPM', 100);
		check_changeBPM.name = 'check_changeBPM';

		tab_group_section.add(stepperLength);
		tab_group_section.add(stepperLengthLabel);
		tab_group_section.add(stepperSectionBPM);
		tab_group_section.add(stepperCopy);
		tab_group_section.add(stepperCopyLabel);
		tab_group_section.add(check_mustHitSection);
		tab_group_section.add(check_altAnim);
		tab_group_section.add(check_changeBPM);
		tab_group_section.add(copyButton);
		tab_group_section.add(clearSectionButton);
		tab_group_section.add(swapSection);

		UI_box.addGroup(tab_group_section);
	}

	var stepperSusLength:FlxUINumericStepper;

	var tab_group_note:FlxUI;
	
	function addNoteUI():Void
	{
		tab_group_note = new FlxUI(null, UI_box);
		tab_group_note.name = 'Note';

		writingNotesText = new FlxUIText(20,100, 0, "");
		writingNotesText.setFormat("Arial",20,FlxColor.WHITE,FlxTextAlign.LEFT,FlxTextBorderStyle.OUTLINE,FlxColor.BLACK);

		stepperSusLength = new FlxUINumericStepper(10, 10, Conductor.stepCrochet / 2, 0, 0, Conductor.stepCrochet * _song.notes[curSection].lengthInSteps * 4);
		stepperSusLength.value = 0;
		stepperSusLength.name = 'note_susLength';

		var stepperSusLengthLabel = new FlxText(74,10,'Note Sustain Length');

		var applyLength:FlxButton = new FlxButton(10, 100, 'Apply Data');

		tab_group_note.add(writingNotesText);
		tab_group_note.add(stepperSusLength);
		tab_group_note.add(stepperSusLengthLabel);
		tab_group_note.add(applyLength);

		UI_box.addGroup(tab_group_note);

		/*player2 = new Character(0,gridBG.y, _song.player2);
		player1 = new Boyfriend(player2.width * 0.2,gridBG.y + player2.height, _song.player1);

		player1.y = player1.y - player1.height;

		player2.setGraphicSize(Std.int(player2.width * 0.2));
		player1.setGraphicSize(Std.int(player1.width * 0.2));

		UI_box.add(player1);
		UI_box.add(player2);*/

	}

	function loadSong(daSong:String):Void
	{
		if (FlxG.sound.music != null)
		{
			FlxG.sound.music.stop();
			// vocals.stop();
		}

		FlxG.sound.playMusic(Paths.inst(daSong), 0.6);

		// WONT WORK FOR TUTORIAL OR TEST SONG!!! REDO LATER
		vocals = new FlxSound().loadEmbedded(Paths.voices(daSong));
		FlxG.sound.list.add(vocals);

		FlxG.sound.music.pause();
		vocals.pause();

		FlxG.sound.music.onComplete = function()
		{
			vocals.pause();
			vocals.time = 0;
			FlxG.sound.music.pause();
			FlxG.sound.music.time = 0;
			changeSection();
		};
	}

	function generateUI():Void
	{
		while (bullshitUI.members.length > 0)
		{
			bullshitUI.remove(bullshitUI.members[0], true);
		}

		// general shit
		var title:FlxText = new FlxText(UI_box.x + 20, UI_box.y + 20, 0);
		bullshitUI.add(title);
		/* 
			var loopCheck = new FlxUICheckBox(UI_box.x + 10, UI_box.y + 50, null, null, "Loops", 100, ['loop check']);
			loopCheck.checked = curNoteSelected.doesLoop;
			tooltips.add(loopCheck, {title: 'Section looping', body: "Whether or not it's a simon says style section", style: tooltipType});
			bullshitUI.add(loopCheck);

		 */
	}

	override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>)
	{
		if (id == FlxUICheckBox.CLICK_EVENT)
		{
			var check:FlxUICheckBox = cast sender;
			var label = check.getLabel().text;
			switch (label)
			{
				case 'Camera Points to P1?':
					_song.notes[curSection].mustHitSection = check.checked;
				case 'Change BPM':
					_song.notes[curSection].changeBPM = check.checked;
					FlxG.log.add('changed bpm shit');
				case "Alternate Animation":
					_song.notes[curSection].altAnim = check.checked;
			}
		}
		else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper))
		{
			var nums:FlxUINumericStepper = cast sender;
			var wname = nums.name;
			FlxG.log.add(wname);
			if (wname == 'section_length')
			{
				if (nums.value <= 4)
					nums.value = 4;
				_song.notes[curSection].lengthInSteps = Std.int(nums.value);
				updateGrid();
			}
			else if (wname == 'song_speed')
			{
				if (nums.value <= 0)
					nums.value = 0;
				_song.speed = nums.value;
			}
			else if (wname == 'song_bpm')
			{
				if (nums.value <= 0)
					nums.value = 1;
				tempBpm = Std.int(nums.value);
				Conductor.mapBPMChanges(_song);
				Conductor.changeBPM(Std.int(nums.value));
			}
			else if (wname == 'note_susLength')
			{
				if (curSelectedNote == null)
					return;

				if (nums.value <= 0)
					nums.value = 0;
				curSelectedNote[2] = nums.value;
				updateGrid();
			}
			else if (wname == 'section_bpm')
			{
				if (nums.value <= 0.1)
					nums.value = 0.1;
				_song.notes[curSection].bpm = Std.int(nums.value);
				updateGrid();
			}else if (wname == 'song_vocalvol')
			{
				if (nums.value <= 0.1)
					nums.value = 0.1;
				vocals.volume = nums.value;
			}else if (wname == 'song_instvol')
			{
				if (nums.value <= 0.1)
					nums.value = 0.1;
				FlxG.sound.music.volume = nums.value;
			}
		}

		// FlxG.log.add(id + " WEED " + sender + " WEED " + data + " WEED " + params);
	}

	var updatedSection:Bool = false;

	/* this function got owned LOL
		function lengthBpmBullshit():Float
		{
			if (_song.notes[curSection].changeBPM)
				return _song.notes[curSection].lengthInSteps * (_song.notes[curSection].bpm / _song.bpm);
			else
				return _song.notes[curSection].lengthInSteps;
	}*/
	function sectionStartTime():Float
	{
		var daBPM:Int = _song.bpm;
		var daPos:Float = 0;
		for (i in 0...curSection)
		{
			if (_song.notes[i].changeBPM)
			{
				daBPM = _song.notes[i].bpm;
			}
			daPos += 4 * (1000 * 60 / daBPM);
		}
		return daPos;
	}

	var writingNotes:Bool = false;

	override function update(elapsed:Float)
	{
		updateHeads();

		curStep = recalculateSteps();

		if (FlxG.keys.justPressed.ALT && UI_box.selected_tab == 0)
		{
			writingNotes = !writingNotes;
		}

		if (writingNotes)
			writingNotesText.text = "WRITING NOTES";
		else
			writingNotesText.text = "";

		Conductor.songPosition = FlxG.sound.music.time;
		_song.song = typingShit.text;

		var upP = controls.UP_P;
		var rightP = controls.RIGHT_P;
		var downP = controls.DOWN_P;
		var leftP = controls.LEFT_P;

		var controlArray:Array<Bool> = [leftP, downP, upP, rightP];

		if ((upP || rightP || downP || leftP) && writingNotes)
		{
			for(i in 0...controlArray.length)
			{
				if (controlArray[i])
				{
					for (n in 0..._song.notes[curSection].sectionNotes.length)
						{
							var note = _song.notes[curSection].sectionNotes[n];
							if (note == null)
								continue;
							if (note[0] == Conductor.songPosition && note[1] % 4 == i)
							{
								trace('GAMING');
								_song.notes[curSection].sectionNotes.remove(note);
							}
						}
					trace('adding note');
					_song.notes[curSection].sectionNotes.push([Conductor.songPosition, i, 0]);
					updateGrid();
				}
			}

		}

		strumLine.y = getYfromStrum((Conductor.songPosition - sectionStartTime()) % (Conductor.stepCrochet * _song.notes[curSection].lengthInSteps));
		
		curRenderedNotes.forEach(function(note:Note)
		{
			if (FlxG.sound.music.playing)
			{
				FlxG.overlap(strumLine, note, function(_, _)
				{
					if(!claps.contains(note))
					{
						claps.push(note);
						if(_song.notes[curSection].mustHitSection) FlxG.sound.play(Paths.sound('CLAP'));
						else FlxG.sound.play(Paths.sound('SNAP'));
					}
				});
			}
		});
		
		/*curRenderedNotes.forEach(function(note:Note) {
			if (strumLine.overlaps(note) && strumLine.y == note.y) // yandere dev type shit
			{
				if (_song.notes[curSection].mustHitSection)
					{
						trace('must hit ' + Math.abs(note.noteData));
						if (note.noteData < 4)
						{
							switch (Math.abs(note.noteData))
							{
								case 2:
									player1.playAnim('singUP', true);
								case 3:
									player1.playAnim('singRIGHT', true);
								case 1:
									player1.playAnim('singDOWN', true);
								case 0:
									player1.playAnim('singLEFT', true);
							}
						}
						if (note.noteData >= 4)
						{
							switch (note.noteData)
							{
								case 6:
									player2.playAnim('singUP', true);
								case 7:
									player2.playAnim('singRIGHT', true);
								case 5:
									player2.playAnim('singDOWN', true);
								case 4:
									player2.playAnim('singLEFT', true);
							}
						}
					}
					else
					{
						trace('hit ' + Math.abs(note.noteData));
						if (note.noteData < 4)
						{
							switch (Math.abs(note.noteData))
							{
								case 2:
									player2.playAnim('singUP', true);
								case 3:
									player2.playAnim('singRIGHT', true);
								case 1:
									player2.playAnim('singDOWN', true);
								case 0:
									player2.playAnim('singLEFT', true);
							}
						}
						if (note.noteData >= 4)
						{
							switch (note.noteData)
							{
								case 6:
									player1.playAnim('singUP', true);
								case 7:
									player1.playAnim('singRIGHT', true);
								case 5:
									player1.playAnim('singDOWN', true);
								case 4:
									player1.playAnim('singLEFT', true);
							}
						}
					}
			}
		});*/

		if (curBeat % 4 == 0 && curStep >= 16 * (curSection + 1))
		{
			trace(curStep);
			trace((_song.notes[curSection].lengthInSteps) * (curSection + 1));
			trace('DUMBSHIT');

			if (_song.notes[curSection + 1] == null)
			{
				addSection();
			}

			changeSection(curSection + 1, false);
		}

		FlxG.watch.addQuick('daBeat', curBeat);
		FlxG.watch.addQuick('daStep', curStep);

		if (FlxG.mouse.justPressed)
		{
			if (FlxG.mouse.overlaps(curRenderedNotes))
			{
				curRenderedNotes.forEach(function(note:Note)
				{
					if (FlxG.mouse.overlaps(note))
					{
						if (FlxG.keys.pressed.CONTROL)
						{
							selectNote(note);
						}
						else
						{
							deleteNote(note);
						}
					}
				});
			}
			else
			{
				if (FlxG.mouse.x > gridBG.x
					&& FlxG.mouse.x < gridBG.x + gridBG.width
					&& FlxG.mouse.y > gridBG.y
					&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSection].lengthInSteps))
				{
					FlxG.log.add('added note');
					addNote();
				}
			}
		}

		if (FlxG.mouse.x > gridBG.x
			&& FlxG.mouse.x < gridBG.x + gridBG.width
			&& FlxG.mouse.y > gridBG.y
			&& FlxG.mouse.y < gridBG.y + (GRID_SIZE * _song.notes[curSection].lengthInSteps))
		{
			dummyArrow.x = Math.floor(FlxG.mouse.x / GRID_SIZE) * GRID_SIZE;
			if (FlxG.keys.pressed.SHIFT)
				dummyArrow.y = FlxG.mouse.y;
			else
				dummyArrow.y = Math.floor(FlxG.mouse.y / GRID_SIZE) * GRID_SIZE;
		}

		if (FlxG.keys.justPressed.ENTER)
		{
			lastSection = curSection;

			PlayState.SONG = _song;
			FlxG.sound.music.stop();
			vocals.stop();
			LoadingState.loadAndSwitchState(new PlayState());
		}

		if (FlxG.keys.justPressed.E)
		{
			changeNoteSustain(Conductor.stepCrochet);
		}
		if (FlxG.keys.justPressed.Q)
		{
			changeNoteSustain(-Conductor.stepCrochet);
		}

		if (FlxG.keys.justPressed.TAB)
		{
			if (FlxG.keys.pressed.SHIFT)
			{
				UI_box.selected_tab -= 1;
				if (UI_box.selected_tab < 0)
					UI_box.selected_tab = 2;
			}
			else
			{
				UI_box.selected_tab += 1;
				if (UI_box.selected_tab >= 3)
					UI_box.selected_tab = 0;
			}
		}

		if (!typingShit.hasFocus)
		{

			if (FlxG.keys.pressed.CONTROL)
			{
				if (FlxG.keys.justPressed.Z && lastNote != null)
				{
					trace(curRenderedNotes.members.contains(lastNote) ? "delete note" : "add note");
					if (curRenderedNotes.members.contains(lastNote))
						deleteNote(lastNote);
					else 
						addNote(lastNote);
				}
			}

			var shiftThing:Int = 1;
			if (FlxG.keys.pressed.SHIFT)
				shiftThing = 4;
			if (!writingNotes)
			{
				if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
					changeSection(curSection + shiftThing);
				if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
					changeSection(curSection - shiftThing);
			}	
			if (FlxG.keys.justPressed.SPACE)
			{
				if (FlxG.sound.music.playing)
				{
					FlxG.sound.music.pause();
					vocals.pause();
					claps.splice(0, claps.length);
				}
				else
				{
					vocals.play();
					FlxG.sound.music.play();
				}
			}

			if (FlxG.keys.justPressed.R)
			{
				if (FlxG.keys.pressed.SHIFT)
					resetSection(true);
				else
					resetSection();
			}

			if (FlxG.mouse.wheel != 0)
			{
				FlxG.sound.music.pause();
				vocals.pause();

				FlxG.sound.music.time -= (FlxG.mouse.wheel * Conductor.stepCrochet * 0.4);
				vocals.time = FlxG.sound.music.time;
			}

			if (!FlxG.keys.pressed.SHIFT)
			{
				if (FlxG.keys.pressed.W || FlxG.keys.pressed.S)
				{
					FlxG.sound.music.pause();
					vocals.pause();

					var daTime:Float = 700 * FlxG.elapsed;

					if (FlxG.keys.pressed.W)
					{
						FlxG.sound.music.time -= daTime;
					}
					else
						FlxG.sound.music.time += daTime;

					vocals.time = FlxG.sound.music.time;
				}
			}
			else
			{
				if (FlxG.keys.justPressed.W || FlxG.keys.justPressed.S)
				{
					FlxG.sound.music.pause();
					vocals.pause();

					var daTime:Float = Conductor.stepCrochet * 2;

					if (FlxG.keys.justPressed.W)
					{
						FlxG.sound.music.time -= daTime;
					}
					else
						FlxG.sound.music.time += daTime;

					vocals.time = FlxG.sound.music.time;
				}
			}
		}

		_song.bpm = tempBpm;

		/* if (FlxG.keys.justPressed.UP)
				Conductor.changeBPM(Conductor.bpm + 1);
			if (FlxG.keys.justPressed.DOWN)
				Conductor.changeBPM(Conductor.bpm - 1); */

		bpmTxt.text = bpmTxt.text = Std.string(FlxMath.roundDecimal(Conductor.songPosition / 1000, 2))
			+ " / "
			+ Std.string(FlxMath.roundDecimal(FlxG.sound.music.length / 1000, 2))
			+ "\nSection: "
			+ curSection 
			+ "\nCurStep: " 
			+ curStep;
		super.update(elapsed);
	}

	function changeNoteSustain(value:Float):Void
	{
		if (curSelectedNote != null)
		{
			if (curSelectedNote[2] != null)
			{
				curSelectedNote[2] += value;
				curSelectedNote[2] = Math.max(curSelectedNote[2], 0);
			}
		}

		updateNoteUI();
		updateGrid();
	}

	override function beatHit() 
	{
		trace('beat');

		super.beatHit();
		if (!player2.animation.curAnim.name.startsWith("sing"))
		{
			player2.playAnim('idle');
		}
		player1.dance();
	}

	function recalculateSteps():Int
	{
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: 0
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (FlxG.sound.music.time > Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		curStep = lastChange.stepTime + Math.floor((FlxG.sound.music.time - lastChange.songTime) / Conductor.stepCrochet);
		updateBeat();

		return curStep;
	}

	function resetSection(songBeginning:Bool = false):Void
	{
		updateGrid();

		FlxG.sound.music.pause();
		vocals.pause();

		// Basically old shit from changeSection???
		FlxG.sound.music.time = sectionStartTime();

		if (songBeginning)
		{
			FlxG.sound.music.time = 0;
			curSection = 0;
		}

		vocals.time = FlxG.sound.music.time;
		updateCurStep();

		updateGrid();
		updateSectionUI();
	}

	function changeSection(sec:Int = 0, ?updateMusic:Bool = true):Void
	{
		trace('changing section' + sec);

		if (_song.notes[sec] != null)
		{
			trace('naw im not null');
			curSection = sec;

			updateGrid();

			if (updateMusic)
			{
				FlxG.sound.music.pause();
				vocals.pause();

				/*var daNum:Int = 0;
					var daLength:Float = 0;
					while (daNum <= sec)
					{
						daLength += lengthBpmBullshit();
						daNum++;
				}*/

				FlxG.sound.music.time = sectionStartTime();
				vocals.time = FlxG.sound.music.time;
				updateCurStep();
			}

			updateGrid();
			updateSectionUI();
		}
		else
			trace('bro wtf I AM NULL');
	}

	function copySection(?sectionNum:Int = 1)
	{
		var daSec = FlxMath.maxInt(curSection, sectionNum);

		for (note in _song.notes[daSec - sectionNum].sectionNotes)
		{
			var strum = note[0] + Conductor.stepCrochet * (_song.notes[daSec].lengthInSteps * sectionNum);

			var copiedNote:Array<Dynamic> = [strum, note[1], note[2]];
			_song.notes[daSec].sectionNotes.push(copiedNote);
		}

		updateGrid();
	}

	function updateSectionUI():Void
	{
		var sec = _song.notes[curSection];

		stepperLength.value = sec.lengthInSteps;
		check_mustHitSection.checked = sec.mustHitSection;
		check_altAnim.checked = sec.altAnim;
		check_changeBPM.checked = sec.changeBPM;
		stepperSectionBPM.value = sec.bpm;
	}

	function updateHeads():Void
	{
		if (check_mustHitSection.checked)
		{
			leftIcon.animation.play(_song.player1);
			rightIcon.animation.play(_song.player2);
		}
		else
		{
			leftIcon.animation.play(_song.player2);
			rightIcon.animation.play(_song.player1);
		}
	}

	function updateNoteUI():Void
	{
		if (curSelectedNote != null)
			stepperSusLength.value = curSelectedNote[2];
	}

	function updateGrid():Void
	{
		remove(gridBG);
		gridBG = FlxGridOverlay.create(GRID_SIZE, GRID_SIZE, GRID_SIZE * 8, GRID_SIZE * _song.notes[curSection].lengthInSteps);
        add(gridBG);

		remove(gridBlackLine);
		gridBlackLine = new FlxSprite(gridBG.x + gridBG.width / 2).makeGraphic(2, Std.int(gridBG.height), FlxColor.BLACK);
		add(gridBlackLine);
		
		while (curRenderedNotes.members.length > 0)
		{
			curRenderedNotes.remove(curRenderedNotes.members[0], true);
		}

		while (curRenderedSustains.members.length > 0)
		{
			curRenderedSustains.remove(curRenderedSustains.members[0], true);
		}

		var sectionInfo:Array<Dynamic> = _song.notes[curSection].sectionNotes;

		if (_song.notes[curSection].changeBPM && _song.notes[curSection].bpm > 0)
		{
			Conductor.changeBPM(_song.notes[curSection].bpm);
			FlxG.log.add('CHANGED BPM!');
		}
		else
		{
			// get last bpm
			var daBPM:Int = _song.bpm;
			for (i in 0...curSection)
				if (_song.notes[i].changeBPM)
					daBPM = _song.notes[i].bpm;
			Conductor.changeBPM(daBPM);
		}

		/* // PORT BULLSHIT, INCASE THERE'S NO SUSTAIN DATA FOR A NOTE
			for (sec in 0..._song.notes.length)
			{
				for (notesse in 0..._song.notes[sec].sectionNotes.length)
				{
					if (_song.notes[sec].sectionNotes[notesse][2] == null)
					{
						trace('SUS NULL');
						_song.notes[sec].sectionNotes[notesse][2] = 0;
					}
				}
			}
		 */

		for (i in sectionInfo)
		{
			var daNoteInfo = i[1];
			var daStrumTime = i[0];
			var daSus = i[2];

			var note:Note = new Note(daStrumTime, daNoteInfo % 4);
			note.sustainLength = daSus;
			note.setGraphicSize(GRID_SIZE, GRID_SIZE);
			note.updateHitbox();
			note.x = Math.floor(daNoteInfo * GRID_SIZE);
			note.y = Math.floor(getYfromStrum((daStrumTime - sectionStartTime()) % (Conductor.stepCrochet * _song.notes[curSection].lengthInSteps)));

			if (curSelectedNote != null)
				if (curSelectedNote[0] == note.strumTime)
					lastNote = note;

			curRenderedNotes.add(note);

			if (daSus > 0)
			{
				var sustainVis:FlxSprite = new FlxSprite(note.x + (GRID_SIZE / 2),
					note.y + GRID_SIZE).makeGraphic(8, Math.floor(FlxMath.remapToRange(daSus, 0, Conductor.stepCrochet * _song.notes[curSection].lengthInSteps, 0, gridBG.height)));
				curRenderedSustains.add(sustainVis);
			}
		}
	}

	private function addSection(lengthInSteps:Int = 16):Void
	{
		var sec:SwagSection = {
			lengthInSteps: lengthInSteps,
			bpm: _song.bpm,
			changeBPM: false,
			mustHitSection: true,
			sectionNotes: [],
			typeOfSection: 0,
			altAnim: false
		};

		_song.notes.push(sec);
	}

	function selectNote(note:Note):Void
	{
		var swagNum:Int = 0;

		for (i in _song.notes[curSection].sectionNotes)
		{
			if (i.strumTime == note.strumTime && i.noteData % 4 == note.noteData)
			{
				curSelectedNote = _song.notes[curSection].sectionNotes[swagNum];
			}

			swagNum += 1;
		}

		updateGrid();
		updateNoteUI();
	}


	function deleteNote(note:Note):Void
		{
			lastNote = note;
			for (i in _song.notes[curSection].sectionNotes)
			{
				if (i[0] == note.strumTime && i[1] % 4 == note.noteData)
				{
					_song.notes[curSection].sectionNotes.remove(i);
				}
			}
	
			updateGrid();
		}

	function clearSection():Void
	{
		_song.notes[curSection].sectionNotes = [];

		updateGrid();
	}

	function clearSong():Void
	{
		for (daSection in 0..._song.notes.length)
		{
			_song.notes[daSection].sectionNotes = [];
		}

		updateGrid();
	}

	private function addNote(?n:Note):Void
	{
		var noteStrum = getStrumTime(dummyArrow.y) + sectionStartTime();
		var noteData = Math.floor(FlxG.mouse.x / GRID_SIZE);
		var noteSus = 0;

		if (n != null)
			_song.notes[curSection].sectionNotes.push([n.strumTime, n.noteData, n.sustainLength]);
		else
			_song.notes[curSection].sectionNotes.push([noteStrum, noteData, noteSus]);

		var thingy = _song.notes[curSection].sectionNotes[_song.notes[curSection].sectionNotes.length - 1];

		curSelectedNote = thingy;

		updateGrid();
		updateNoteUI();

		autosaveSong();
	}

	function getStrumTime(yPos:Float):Float
	{
		return FlxMath.remapToRange(yPos, gridBG.y, gridBG.y + gridBG.height, 0, 16 * Conductor.stepCrochet);
	}

	function getYfromStrum(strumTime:Float):Float
	{
		return FlxMath.remapToRange(strumTime, 0, 16 * Conductor.stepCrochet, gridBG.y, gridBG.y + gridBG.height);
	}

	/*
		function calculateSectionLengths(?sec:SwagSection):Int
		{
			var daLength:Int = 0;

			for (i in _song.notes)
			{
				var swagLength = i.lengthInSteps;

				if (i.typeOfSection == Section.COPYCAT)
					swagLength * 2;

				daLength += swagLength;

				if (sec != null && sec == i)
				{
					trace('swag loop??');
					break;
				}
			}

			return daLength;
	}*/
	private var daSpacing:Float = 0.3;

	function loadLevel():Void
	{
		trace(_song.notes);
	}

	function getNotes():Array<Dynamic>
	{
		var noteData:Array<Dynamic> = [];

		for (i in _song.notes)
		{
			noteData.push(i.sectionNotes);
		}

		return noteData;
	}

	function loadJson(song:String):Void
	{
		PlayState.SONG = Song.loadFromJson(song.toLowerCase(), song.toLowerCase());
		LoadingState.loadAndSwitchState(new ChartingState());
	}

	function loadAutosave():Void
	{
		PlayState.SONG = Song.parseJSONshit(FlxG.save.data.autosave);
		LoadingState.loadAndSwitchState(new ChartingState());
	}

	function autosaveSong():Void
	{
		FlxG.save.data.autosave = Json.stringify({
			"song": _song
		});
		FlxG.save.flush();
	}

	private function saveLevel()
	{
		var json = {
			"song": _song
		};

		var data:String = Json.stringify(json);

		if ((data != null) && (data.length > 0))
		{
			_file = new FileReference();
			_file.addEventListener(Event.COMPLETE, onSaveComplete);
			_file.addEventListener(Event.CANCEL, onSaveCancel);
			_file.addEventListener(IOErrorEvent.IO_ERROR, onSaveError);
			_file.save(data.trim(), _song.song.toLowerCase() + ".json");
		}
	}

	function onSaveComplete(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.notice("Successfully saved LEVEL DATA.");
	}

	/**
	 * Called when the save file dialog is cancelled.
	 */
	function onSaveCancel(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
	}

	/**
	 * Called if there is an error while saving the gameplay recording.
	 */
	function onSaveError(_):Void
	{
		_file.removeEventListener(Event.COMPLETE, onSaveComplete);
		_file.removeEventListener(Event.CANCEL, onSaveCancel);
		_file.removeEventListener(IOErrorEvent.IO_ERROR, onSaveError);
		_file = null;
		FlxG.log.error("Problem saving Level data");
	}
}
@:allow(flixel.FlxG)
class FlxGame extends Sprite
{
	/**
	 * Framerate to use on focus lost. Default is `10`.
	 */
	public var focusLostFramerate:Int = 10;

	#if FLX_RECORD
	/**
	 * Flag for whether a replay is currently playing.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	public var replaying(default, null):Bool = false;

	/**
	 * Flag for whether a new recording is being made.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	public var recording(default, null):Bool = false;
	#end

	#if FLX_SOUND_TRAY
	/**
	 * The sound tray display container.
	 */
	public var soundTray(default, null):FlxSoundTray;
	#end

	#if FLX_DEBUG
	/**
	 * The debugger overlay object.
	 */
	public var debugger(default, null):FlxDebugger;
	#end

	/**
	 * Time in milliseconds that has passed (amount of "ticks" passed) since the game has started.
	 */
	public var ticks(default, null):Int = 0;

	/**
	 * Enables or disables the filters set via `setFilters()`.
	 */
	public var filtersEnabled:Bool = true;

	/**
	 * A flag for triggering the `preGameStart` and `postGameStart` "events".
	 */
	@:allow(flixel.system.FlxSplash)
	var _gameJustStarted:Bool = false;

	/**
	 * Class type of the initial/first game state for the game, usually `MenuState` or something like that.
	 */
	var _initialState:Class<FlxState>;

	/**
	 * Current game state.
	 */
	var _state:FlxState;

	/**
	 * Total number of milliseconds elapsed since game start.
	 */
	var _total:Int = 0;

	/**
	 * Time stamp of game startup. Needed on JS where `Lib.getTimer()`
	 * returns time stamp of current date, not the time passed since app start.
	 */
	var _startTime:Int = 0;

	/**
	 * Total number of milliseconds elapsed since last update loop.
	 * Counts down as we step through the game loop.
	 */
	var _accumulator:Float;

	/**
	 * Milliseconds of time since last step.
	 */
	var _elapsedMS:Float;

	/**
	 * Milliseconds of time per step of the game loop. e.g. 60 fps = 16ms.
	 */
	var _stepMS:Float;

	/**
	 * Optimization so we don't have to divide step by 1000 to get its value in seconds every frame.
	 */
	var _stepSeconds:Float;

	/**
	 * Max allowable accumulation (see `_accumulator`).
	 * Should always (and automatically) be set to roughly 2x the stage framerate.
	 */
	var _maxAccumulation:Float;

	/**
	 * Whether the game lost focus.
	 */
	var _lostFocus:Bool = false;

	/**
	 * The filters array to be applied to the game.
	 */
	var _filters:Array<BitmapFilter>;

	#if (desktop && lime_legacy)
	/**
	 * Ugly workaround to ensure consistent behaviour between flash and cpp
	 * (the focus event should not fire when the game starts up!)
	 */
	var _onFocusFiredOnce:Bool = false;
	#end

	#if FLX_FOCUS_LOST_SCREEN
	/**
	 * The "focus lost" screen.
	 */
	var _focusLostScreen:FlxFocusLostScreen;
	#end

	/**
	 * Mouse cursor.
	 */
	@:allow(flixel.FlxG)
	@:allow(flixel.system.frontEnds.CameraFrontEnd)
	var _inputContainer:Sprite;

	#if FLX_SOUND_TRAY
	/**
	 * Change this after calling `super()` in the `FlxGame` constructor
	 * to use a customized sound tray based on `FlxSoundTray`.
	 */
	var _customSoundTray:Class<FlxSoundTray> = FlxSoundTray;
	#end

	#if FLX_FOCUS_LOST_SCREEN
	/**
	 * Change this after calling `super()` in the `FlxGame` constructor
	 * to use a customized screen which will be show when the application lost focus.
	 */
	var _customFocusLostScreen:Class<FlxFocusLostScreen> = FlxFocusLostScreen;
	#end

	/**
	 * Whether the splash screen should be skipped.
	 */
	var _skipSplash:Bool = false;

	#if desktop
	/**
	 * Should we start fullscreen or not? This is useful if you want to load fullscreen settings from a
	 * `FlxSave` and set it when the game starts, instead of having it hard-set in your `Project.xml`.
	 */
	var _startFullscreen:Bool = false;
	#end

	/**
	 * If a state change was requested, the new state object is stored here until we switch to it.
	 */
	var _requestedState:FlxState;

	/**
	 * A flag for keeping track of whether a game reset was requested or not.
	 */
	var _resetGame:Bool = false;

	#if FLX_RECORD
	/**
	 * Container for a game replay object.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	var _replay:FlxReplay;

	/**
	 * Flag for whether a playback of a recording was requested.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	var _replayRequested:Bool = false;

	/**
	 * Flag for whether a new recording was requested.
	 */
	@:allow(flixel.system.frontEnds.VCRFrontEnd)
	var _recordingRequested:Bool = false;
	#end

	#if FLX_POST_PROCESS
	/**
	 * `Sprite` for postprocessing effects
	 */
	var postProcessLayer:Sprite = new Sprite();

	/**
	 * Post process effects active on the `postProcessLayer`.
	 */
	var postProcesses:Array<PostProcess> = [];
	#end

	/**
	 * Instantiate a new game object.
	 *
	 * @param GameWidth       The width of your game in game pixels, not necessarily final display pixels (see `Zoom`).
	 *                        If equal to `0`, the window width specified in the `Project.xml` is used.
	 * @param GameHeight      The height of your game in game pixels, not necessarily final display pixels (see `Zoom`).
	 *                        If equal to `0`, the window height specified in the `Project.xml` is used.
	 * @param InitialState    The class name of the state you want to create and switch to first (e.g. `MenuState`).
	 * @param Zoom            The default level of zoom for the game's cameras (e.g. `2` = all pixels are now drawn at 2x).
	 * @param UpdateFramerate How frequently the game should update (default is `60` times per second).
	 * @param DrawFramerate   Sets the actual display / draw framerate for the game (default is `60` times per second).
	 * @param SkipSplash      Whether you want to skip the flixel splash screen with `FLX_NO_DEBUG`.
	 * @param StartFullscreen Whether to start the game in fullscreen mode (desktop targets only).
	 */
	public function new(GameWidth:Int = 0, GameHeight:Int = 0, ?InitialState:Class<FlxState>, Zoom:Float = 1, UpdateFramerate:Int = 60,
			DrawFramerate:Int = 60, SkipSplash:Bool = false, StartFullscreen:Bool = false)
	{
		super();

		#if desktop
		_startFullscreen = StartFullscreen;
		#end

		// Super high priority init stuff
		_inputContainer = new Sprite();

		if (GameWidth == 0)
			GameWidth = FlxG.stage.stageWidth;
		if (GameHeight == 0)
			GameHeight = FlxG.stage.stageHeight;

		// Basic display and update setup stuff
		FlxG.init(this, GameWidth, GameHeight, Zoom);

		FlxG.updateFramerate = UpdateFramerate;
		FlxG.drawFramerate = DrawFramerate;
		_accumulator = _stepMS;
		_skipSplash = SkipSplash;

		#if FLX_RECORD
		_replay = new FlxReplay();
		#end

		// Then get ready to create the game object for real
		_initialState = (InitialState == null) ? FlxState : InitialState;

		addEventListener(Event.ADDED_TO_STAGE, create);
	}

	/**
	 * Sets the filter array to be applied to the game.
	 */
	public function setFilters(filters:Array<BitmapFilter>):Void
	{
		_filters = filters;
	}

	/**
	 * Used to instantiate the guts of the flixel game object once we have a valid reference to the root.
	 */
	function create(_):Void
	{
		if (stage == null)
			return;

		removeEventListener(Event.ADDED_TO_STAGE, create);

		_startTime = getTimer();
		_total = getTicks();

		#if desktop
		FlxG.fullscreen = _startFullscreen;
		#end

		// Set up the view window and double buffering
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.align = StageAlign.TOP_LEFT;
		stage.frameRate = FlxG.drawFramerate;

		addChild(_inputContainer);

		#if FLX_POST_PROCESS
		if (OpenGLView.isSupported)
			addChild(postProcessLayer);
		#end

		// Creating the debugger overlay
		#if FLX_DEBUG
		debugger = new FlxDebugger(FlxG.stage.stageWidth, FlxG.stage.stageHeight);
		addChild(debugger);
		#end

		// No need for overlays on mobile.
		#if !mobile
		// Volume display tab
		#if FLX_SOUND_TRAY
		soundTray = Type.createInstance(_customSoundTray, []);
		addChild(soundTray);
		#end

		#if FLX_FOCUS_LOST_SCREEN
		_focusLostScreen = Type.createInstance(_customFocusLostScreen, []);
		addChild(_focusLostScreen);
		#end
		#end

		// Focus gained/lost monitoring
		#if (desktop && openfl <= "4.0.0")
		stage.addEventListener(FocusEvent.FOCUS_OUT, onFocusLost);
		stage.addEventListener(FocusEvent.FOCUS_IN, onFocus);
		#else
		stage.addEventListener(Event.DEACTIVATE, onFocusLost);
		stage.addEventListener(Event.ACTIVATE, onFocus);
		#end

		// Instantiate the initial state
		resetGame();
		switchState();

		if (FlxG.updateFramerate < FlxG.drawFramerate)
			FlxG.log.warn("FlxG.updateFramerate: The update framerate shouldn't be smaller" + " than the draw framerate, since it can slow down your game.");

		// Finally, set up an event for the actual game loop stuff.
		stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);

		// We need to listen for resize event which means new context
		// it means that we need to recreate BitmapDatas of dumped tilesheets
		stage.addEventListener(Event.RESIZE, onResize);

		// make sure the cursor etc are properly scaled from the start
		resizeGame(FlxG.stage.stageWidth, FlxG.stage.stageHeight);

		Assets.addEventListener(Event.CHANGE, FlxG.bitmap.onAssetsReload);
	}

	function onFocus(_):Void
	{
		#if flash
		if (!_lostFocus)
			return; // Don't run this function twice (bug in standalone flash player)
		#end

		#if (desktop && lime_legacy)
		// make sure the on focus event doesn't fire on startup
		if (!_onFocusFiredOnce)
		{
			_onFocusFiredOnce = true;
			return;
		}
		#end

		#if mobile
		// just check if device orientation has been changed
		onResize(_);
		#end

		_lostFocus = false;
		FlxG.signals.focusGained.dispatch();
		_state.onFocus();

		if (!FlxG.autoPause)
			return;

		#if FLX_FOCUS_LOST_SCREEN
		if (_focusLostScreen != null)
			_focusLostScreen.visible = false;
		#end

		#if FLX_DEBUG
		debugger.stats.onFocus();
		#end

		stage.frameRate = FlxG.drawFramerate;
		#if FLX_SOUND_SYSTEM
		FlxG.sound.onFocus();
		#end
		FlxG.inputs.onFocus();
	}

	function onFocusLost(event:Event):Void
	{
		#if next
		if (event != null && event.target != FlxG.stage)
			return;
		#end

		#if flash
		if (_lostFocus)
			return; // Don't run this function twice (bug in standalone flash player)
		#end

		_lostFocus = true;
		FlxG.signals.focusLost.dispatch();
		_state.onFocusLost();

		if (!FlxG.autoPause)
			return;

		#if FLX_FOCUS_LOST_SCREEN
		if (_focusLostScreen != null)
			_focusLostScreen.visible = true;
		#end

		#if FLX_DEBUG
		debugger.stats.onFocusLost();
		#end

		stage.frameRate = focusLostFramerate;
		#if FLX_SOUND_SYSTEM
		FlxG.sound.onFocusLost();
		#end
		FlxG.inputs.onFocusLost();
	}

	@:allow(flixel.FlxG)
	function onResize(_):Void
	{
		var width:Int = FlxG.stage.stageWidth;
		var height:Int = FlxG.stage.stageHeight;

		#if !flash
		if (FlxG.renderTile)
			FlxG.bitmap.onContext();
		#end

		resizeGame(width, height);
	}

	function resizeGame(width:Int, height:Int):Void
	{
		FlxG.resizeGame(width, height);

		_state.onResize(width, height);

		FlxG.cameras.resize();
		FlxG.signals.gameResized.dispatch(width, height);

		#if FLX_DEBUG
		debugger.onResize(width, height);
		#end

		#if FLX_FOCUS_LOST_SCREEN
		if (_focusLostScreen != null)
			_focusLostScreen.draw();
		#end

		#if FLX_SOUND_TRAY
		if (soundTray != null)
			soundTray.screenCenter();
		#end

		#if FLX_POST_PROCESS
		for (postProcess in postProcesses)
			postProcess.rebuild();
		#end
	}

	/**
	 * Handles the `onEnterFrame` call and figures out how many updates and draw calls to do.
	 */
	function onEnterFrame(_):Void
	{
		ticks = getTicks();
		_elapsedMS = ticks - _total;
		_total = ticks;

		#if FLX_SOUND_TRAY
		if (soundTray != null && soundTray.active)
			soundTray.update(_elapsedMS);
		#end

		if (!_lostFocus || !FlxG.autoPause)
		{
			if (FlxG.vcr.paused)
			{
				if (FlxG.vcr.stepRequested)
				{
					FlxG.vcr.stepRequested = false;
				}
				else if (_state == _requestedState) // don't pause a state switch request
				{
					#if FLX_DEBUG
					debugger.update();
					// If the interactive debug is active, the screen must
					// be rendered because the user might be doing changes
					// to game objects (e.g. moving things around).
					if (debugger.interaction.isActive())
					{
						draw();
					}
					#end
					return;
				}
			}

			if (FlxG.fixedTimestep)
			{
				_accumulator += _elapsedMS;
				_accumulator = (_accumulator > _maxAccumulation) ? _maxAccumulation : _accumulator;

				while (_accumulator >= _stepMS)
				{
					step();
					_accumulator -= _stepMS;
				}
			}
			else
			{
				step();
			}

			#if FLX_DEBUG
			FlxBasic.visibleCount = 0;
			#end

			draw();

			#if FLX_DEBUG
			debugger.stats.visibleObjects(FlxBasic.visibleCount);
			debugger.update();
			#end
		}
	}

	/**
	 * Internal method to create a new instance of `_initialState` and reset the game.
	 * This gets called when the game is created, as well as when a new state is requested.
	 */
	inline function resetGame():Void
	{
		FlxG.signals.preGameReset.dispatch();

		#if FLX_DEBUG
		_skipSplash = true;
		#end

		if (_skipSplash || FlxSplash.nextState != null) // already played
		{
			_requestedState = cast Type.createInstance(_initialState, []);
			if (FlxSplash.nextState == null)
				_gameJustStarted = true;
		}
		else
		{
			FlxSplash.nextState = _initialState;
			_requestedState = new FlxSplash();
			_skipSplash = true; // only play it once
		}

		#if FLX_DEBUG
		if ((_requestedState is FlxSubState))
			throw "You can't set FlxSubState class instance as the state for you game";
		#end

		FlxG.reset();

		FlxG.signals.postGameReset.dispatch();
	}

	/**
	 * If there is a state change requested during the update loop,
	 * this function handles actual destroying the old state and related processes,
	 * and calls creates on the new state and plugs it into the game object.
	 */
	function switchState():Void
	{
		// Basic reset stuff
		FlxG.cameras.reset();
		FlxG.inputs.onStateSwitch();
		#if FLX_SOUND_SYSTEM
		FlxG.sound.destroy();
		#end

		FlxG.signals.preStateSwitch.dispatch();

		#if FLX_RECORD
		FlxRandom.updateStateSeed();
		#end

		// Destroy the old state (if there is an old state)
		if (_state != null)
			_state.destroy();

		// we need to clear bitmap cache only after previous state is destroyed, which will reset useCount for FlxGraphic objects
		FlxG.bitmap.clearCache();

		// Finally assign and create the new state
		_state = _requestedState;

		if (_gameJustStarted)
			FlxG.signals.preGameStart.dispatch();

		FlxG.signals.preStateCreate.dispatch(_state);

		_state.create();

		if (_gameJustStarted)
			gameStart();

		#if FLX_DEBUG
		debugger.console.registerObject("state", _state);
		#end

		FlxG.signals.postStateSwitch.dispatch();
	}

	function gameStart():Void
	{
		FlxG.signals.postGameStart.dispatch();
		_gameJustStarted = false;
	}

	/**
	 * This is the main game update logic section.
	 * The `onEnterFrame()` handler is in charge of calling this
	 * the appropriate number of times each frame.
	 * This block handles state changes, replays, all that good stuff.
	 */
	function step():Void
	{
		// Handle game reset request
		if (_resetGame)
		{
			resetGame();
			_resetGame = false;
		}

		handleReplayRequests();

		#if FLX_DEBUG
		// Finally actually step through the game physics
		FlxBasic.activeCount = 0;
		#end

		update();

		#if FLX_DEBUG
		debugger.stats.activeObjects(FlxBasic.activeCount);
		#end
	}

	function handleReplayRequests():Void
	{
		#if FLX_RECORD
		// Handle replay-related requests
		if (_recordingRequested)
		{
			_recordingRequested = false;
			_replay.create(FlxRandom.getRecordingSeed());
			recording = true;

			#if FLX_DEBUG
			debugger.vcr.recording();
			FlxG.log.notice("Starting new flixel gameplay record.");
			#end
		}
		else if (_replayRequested)
		{
			_replayRequested = false;
			_replay.rewind();
			FlxG.random.initialSeed = _replay.seed;

			#if FLX_DEBUG
			debugger.vcr.playingReplay();
			#end

			replaying = true;
		}
		#end
	}

	/**
	 * This function is called by `step()` and updates the actual game state.
	 * May be called multiple times per "frame" or draw call.
	 */
	function update():Void
	{
		if (!_state.active || !_state.exists)
			return;

		if (_state != _requestedState)
			switchState();

		#if FLX_DEBUG
		if (FlxG.debugger.visible)
			ticks = getTicks();
		#end

		updateElapsed();

		FlxG.signals.preUpdate.dispatch();

		updateInput();

		#if FLX_POST_PROCESS
		if (postProcesses[0] != null)
			postProcesses[0].update(FlxG.elapsed);
		#end

		#if FLX_SOUND_SYSTEM
		FlxG.sound.update(FlxG.elapsed);
		#end
		FlxG.plugins.update(FlxG.elapsed);

		_state.tryUpdate(FlxG.elapsed);

		FlxG.cameras.update(FlxG.elapsed);
		FlxG.signals.postUpdate.dispatch();

		#if FLX_DEBUG
		debugger.stats.flixelUpdate(getTicks() - ticks);
		#end

		#if FLX_POINTER_INPUT
		FlxArrayUtil.clearArray(FlxG.swipes);
		#end

		filters = filtersEnabled ? _filters : null;
	}

	function updateElapsed():Void
	{
		if (FlxG.fixedTimestep)
		{
			FlxG.elapsed = FlxG.timeScale * _stepSeconds; // fixed timestep
		}
		else
		{
			FlxG.elapsed = FlxG.timeScale * (_elapsedMS / 1000); // variable timestep

			var max = FlxG.maxElapsed * FlxG.timeScale;
			if (FlxG.elapsed > max)
				FlxG.elapsed = max;
		}
	}

	function updateInput():Void
	{
		#if FLX_RECORD
		if (replaying)
		{
			_replay.playNextFrame();

			if (FlxG.vcr.timeout > 0)
			{
				FlxG.vcr.timeout -= _stepMS;

				if (FlxG.vcr.timeout <= 0)
				{
					if (FlxG.vcr.replayCallback != null)
					{
						FlxG.vcr.replayCallback();
						FlxG.vcr.replayCallback = null;
					}
					else
					{
						FlxG.vcr.stopReplay();
					}
				}
			}

			if (replaying && _replay.finished)
			{
				FlxG.vcr.stopReplay();

				if (FlxG.vcr.replayCallback != null)
				{
					FlxG.vcr.replayCallback();
					FlxG.vcr.replayCallback = null;
				}
			}

			#if FLX_DEBUG
			debugger.vcr.updateRuntime(_stepMS);
			#end
		}
		else
		{
			FlxG.inputs.update();
		}
		#else
		FlxG.inputs.update();
		#end

		#if FLX_RECORD
		if (recording)
		{
			_replay.recordFrame();

			#if FLX_DEBUG
			debugger.vcr.updateRuntime(_stepMS);
			#end
		}
		#end
	}

	/**
	 * Goes through the game state and draws all the game objects and special effects.
	 */
	function draw():Void
	{
		if (!_state.visible || !_state.exists)
			return;

		#if FLX_DEBUG
		if (FlxG.debugger.visible)
			ticks = getTicks();
		#end

		FlxG.signals.preDraw.dispatch();

		if (FlxG.renderTile)
			FlxDrawBaseItem.drawCalls = 0;

		#if FLX_POST_PROCESS
		if (postProcesses[0] != null)
			postProcesses[0].capture();
		#end

		FlxG.cameras.lock();

		FlxG.plugins.draw();

		_state.draw();

		if (FlxG.renderTile)
		{
			FlxG.cameras.render();

			#if FLX_DEBUG
			debugger.stats.drawCalls(FlxDrawBaseItem.drawCalls);
			#end
		}

		FlxG.cameras.unlock();

		FlxG.signals.postDraw.dispatch();

		#if FLX_DEBUG
		debugger.stats.flixelDraw(getTicks() - ticks);
		#end
	}

	inline function getTicks()
	{
		return getTimer() - _startTime;
	}

	dynamic function getTimer():Int
	{
		// expensive, only call if necessary
		return Lib.getTimer();
	}
}
	package flixel.tweens.motion;

import flixel.math.FlxPoint;

/**
 * Determines motion along p1 quadratic curve.
 */
class QuadMotion extends Motion
{
	/**
	 * The distance of the entire curve.
	 */
	public var distance(get, never):Float;

	// Curve information.
	var _distance:Float = -1;
	var _fromX:Float = 0;
	var _fromY:Float = 0;
	var _toX:Float = 0;
	var _toY:Float = 0;
	var _controlX:Float = 0;
	var _controlY:Float = 0;

	/**
	 * Starts moving along the curve.
	 *
	 * @param	FromX			X start.
	 * @param	FromY			Y start.
	 * @param	ControlX		X control, used to determine the curve.
	 * @param	ControlY		Y control, used to determine the curve.
	 * @param	ToX				X finish.
	 * @param	ToY				Y finish.
	 * @param	DurationOrSpeed	Duration or speed of the movement.
	 * @param	UseDuration		Duration of the movement.
	 */
	public function setMotion(FromX:Float, FromY:Float, ControlX:Float, ControlY:Float, ToX:Float, ToY:Float, DurationOrSpeed:Float,
			UseDuration:Bool = true):QuadMotion
	{
		_distance = -1;
		x = _fromX = FromX;
		y = _fromY = FromY;
		_controlX = ControlX;
		_controlY = ControlY;
		_toX = ToX;
		_toY = ToY;

		if (UseDuration)
		{
			duration = DurationOrSpeed;
		}
		else
		{
			duration = distance / DurationOrSpeed;
		}

		start();

		return this;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		x = _fromX * (1 - scale) * (1 - scale) + _controlX * 2 * (1 - scale) * scale + _toX * scale * scale;
		y = _fromY * (1 - scale) * (1 - scale) + _controlY * 2 * (1 - scale) * scale + _toY * scale * scale;
		if (finished)
		{
			postUpdate();
		}
	}

	function get_distance():Float
	{
		if (_distance >= 0)
			return _distance;

		var p1 = FlxPoint.get();
		var p2 = FlxPoint.get();
		p1.x = x - 2 * _controlX + _toX;
		p1.y = y - 2 * _controlY + _toY;
		p2.x = 2 * _controlX - 2 * x;
		p2.y = 2 * _controlY - 2 * y;
		var a:Float = 4 * (p1.x * p1.x + p1.y * p1.y),
			b:Float = 4 * (p1.x * p2.x + p1.y * p2.y),
			c:Float = p2.x * p2.x + p2.y * p2.y,
			abc:Float = 2 * Math.sqrt(a + b + c),
			a2:Float = Math.sqrt(a),
			a32:Float = 2 * a * a2,
			c2:Float = 2 * Math.sqrt(c),
			ba:Float = b / a2;

		p1.put();
		p2.put();

		return (a32 * abc + a2 * b * (abc - c2) + (4 * c * a - b * b) * Math.log((2 * a2 + ba + abc) / (ba + c2))) / (4 * a32);
	}
}
	class AngleTween extends FlxTween
{
	public var angle(default, null):Float;

	/**
	 * Optional sprite object whose angle to tween
	 */
	public var sprite(default, null):FlxSprite;

	var _start:Float;
	var _range:Float;

	/**
	 * Clean up references
	 */
	override public function destroy()
	{
		super.destroy();
		sprite = null;
	}

	/**
	 * Tweens the value from one angle to another.
	 *
	 * @param	FromAngle		Start angle.
	 * @param	ToAngle			End angle.
	 * @param	Duration		Duration of the tween.
	 */
	public function tween(FromAngle:Float, ToAngle:Float, Duration:Float, ?Sprite:FlxSprite):AngleTween
	{
		_start = angle = FromAngle;
		_range = ToAngle - angle;
		duration = Duration;
		sprite = Sprite;
		if (sprite != null)
		{
			sprite.angle = angle % 360;
		}
		start();
		return this;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);
		angle = _start + _range * scale;

		if (sprite != null)
		{
			var spriteAngle:Float = angle % 0;
			sprite.angle = spriteAngle;
		}
	}
	
	override function isTweenOf(object:Dynamic, ?field:String):Bool
	{
		return sprite == object && (field == null || field == "angle");
	}
}
	class FlxVirtualPad extends FlxSpriteGroup
{
	public var buttonA:FlxButton;
	public var buttonB:FlxButton;
	public var buttonC:FlxButton;
	public var buttonY:FlxButton;
	public var buttonX:FlxButton;
	public var buttonLeft:FlxButton;
	public var buttonUp:FlxButton;
	public var buttonRight:FlxButton;
	public var buttonDown:FlxButton;

	/**
	 * Group of directions buttons.
	 */
	public var dPad:FlxSpriteGroup;

	/**
	 * Group of action buttons.
	 */
	public var actions:FlxSpriteGroup;

	/**
	 * Create a gamepad which contains 4 directional buttons and 4 action buttons.
	 *
	 * @param   DPadMode     The D-Pad mode. `FULL` for example.
	 * @param   ActionMode   The action buttons mode. `A_B_C` for example.
	 */
	public function new(?DPad:FlxDPadMode, ?Action:FlxActionMode)
	{
		super();
		scrollFactor.set();

		if (DPad == null)
			DPad = FULL;
		if (Action == null)
			Action = A_B_C;

		dPad = new FlxSpriteGroup();
		dPad.scrollFactor.set();

		actions = new FlxSpriteGroup();
		actions.scrollFactor.set();

		switch (DPad)
		{
			case UP_DOWN:
				dPad.add(add(buttonUp = createButton(0, FlxG.height - 85, 44, 45, "up")));
				dPad.add(add(buttonDown = createButton(0, FlxG.height - 45, 44, 45, "down")));
			case LEFT_RIGHT:
				dPad.add(add(buttonLeft = createButton(0, FlxG.height - 45, 44, 45, "left")));
				dPad.add(add(buttonRight = createButton(42, FlxG.height - 45, 44, 45, "right")));
			case UP_LEFT_RIGHT:
				dPad.add(add(buttonUp = createButton(35, FlxG.height - 81, 44, 45, "up")));
				dPad.add(add(buttonLeft = createButton(0, FlxG.height - 45, 44, 45, "left")));
				dPad.add(add(buttonRight = createButton(69, FlxG.height - 45, 44, 45, "right")));
			case FULL:
				dPad.add(add(buttonUp = createButton(35, FlxG.height - 116, 44, 45, "up")));
				dPad.add(add(buttonLeft = createButton(0, FlxG.height - 81, 44, 45, "left")));
				dPad.add(add(buttonRight = createButton(69, FlxG.height - 81, 44, 45, "right")));
				dPad.add(add(buttonDown = createButton(35, FlxG.height - 45, 44, 45, "down")));
			case NONE: // do nothing
		}

		switch (Action)
		{
			case A:
				actions.add(add(buttonA = createButton(FlxG.width - 44, FlxG.height - 45, 44, 45, "a")));
			case A_B:
				actions.add(add(buttonA = createButton(FlxG.width - 44, FlxG.height - 45, 44, 45, "a")));
				actions.add(add(buttonB = createButton(FlxG.width - 86, FlxG.height - 45, 44, 45, "b")));
			case A_B_C:
				actions.add(add(buttonA = createButton(FlxG.width - 128, FlxG.height - 45, 44, 45, "a")));
				actions.add(add(buttonB = createButton(FlxG.width - 86, FlxG.height - 45, 44, 45, "b")));
				actions.add(add(buttonC = createButton(FlxG.width - 44, FlxG.height - 45, 44, 45, "c")));
			case A_B_X_Y:
				actions.add(add(buttonY = createButton(FlxG.width - 86, FlxG.height - 85, 44, 45, "y")));
				actions.add(add(buttonX = createButton(FlxG.width - 44, FlxG.height - 85, 44, 45, "x")));
				actions.add(add(buttonB = createButton(FlxG.width - 86, FlxG.height - 45, 44, 45, "b")));
				actions.add(add(buttonA = createButton(FlxG.width - 44, FlxG.height - 45, 44, 45, "a")));
			case NONE: // do nothing
		}
	}

	override public function destroy():Void
	{
		super.destroy();

		dPad = FlxDestroyUtil.destroy(dPad);
		actions = FlxDestroyUtil.destroy(actions);

		dPad = null;
		actions = null;
		buttonA = null;
		buttonB = null;
		buttonC = null;
		buttonY = null;
		buttonX = null;
		buttonLeft = null;
		buttonUp = null;
		buttonDown = null;
		buttonRight = null;
	}

	/**
	 * @param   X          The x-position of the button.
	 * @param   Y          The y-position of the button.
	 * @param   Width      The width of the button.
	 * @param   Height     The height of the button.
	 * @param   Graphic    The image of the button. It must contains 3 frames (`NORMAL`, `HIGHLIGHT`, `PRESSED`).
	 * @param   Callback   The callback for the button.
	 * @return  The button
	 */
	public function createButton(X:Float, Y:Float, Width:Int, Height:Int, Graphic:String, ?OnClick:Void->Void):FlxButton
	{
		var button = new FlxButton(X, Y);
		var frame = FlxAssets.getVirtualInputFrames().getByName(Graphic);
		button.frames = FlxTileFrames.fromFrame(frame, FlxPoint.get(Width, Height));
		button.resetSizeFromFrame();
		button.solid = false;
		button.immovable = true;
		button.scrollFactor.set();

		#if FLX_DEBUG
		button.ignoreDrawDebug = true;
		#end

		if (OnClick != null)
			button.onDown.callback = OnClick;

		return button;
	}
}

enum FlxDPadMode
{
	NONE;
	UP_DOWN;
	LEFT_RIGHT;
	UP_LEFT_RIGHT;
	FULL;
}

enum FlxActionMode
{
	NONE;
	A;
	A_B;
	A_B_C;
	A_B_X_Y;
}
	class Screen
{
	/**
	 * Controls how the game scale changes when the window is resized.
	 */
	public var scaleMode:ScaleMode = new ScaleMode();

	/**
	 * Constructor.
	 */
	@:allow(haxepunk)
	function new() {}

	/**
	 * Resizes the screen.
	 */
	@:dox(hide)
	@:allow(haxepunk.HXP)
	function resize(width:Int, height:Int)
	{
		var oldWidth:Int = HXP.width,
			oldHeight:Int = HXP.height;

		scaleMode.resize(width, height);

		width = HXP.width = Std.int((HXP.screen.width + 0.5) / HXP.screen.scaleX);
		height = HXP.height = Std.int((HXP.screen.height + 0.5) / HXP.screen.scaleY);
	}

	/**
	 * Refresh color of the screen.
	 */
	public var color:Color = Color.Black;

	/**
	 * X offset of the screen.
	 */
	public var x:Int = 0;

	/**
	 * Y offset of the screen.
	 */
	public var y:Int = 0;

	/**
	 * Width of the screen.
	 */
	@:allow(haxepunk.screen)
	public var width(default, null):Int = 0;

	/**
	 * Height of the screen.
	 */
	@:allow(haxepunk.screen)
	public var height(default, null):Int = 0;

	/**
	 * X scale of the screen.
	 */
	public var scaleX(default, set):Float = 1;
	function set_scaleX(value:Float):Float
	{
		scaleX = value;
		HXP.needsResize = true;
		return scaleX;
	}

	/**
	 * Y scale of the screen.
	 */
	public var scaleY(default, set):Float = 1;
	function set_scaleY(value:Float):Float
	{
		scaleY = value;
		HXP.needsResize = true;
		return scaleY;
	}

	/**
	 * X position of the mouse on the screen.
	 */
	public var mouseX(get, null):Int;
	inline function get_mouseX():Int return Std.int((HXP.app.getMouseX() - x) / scaleX);

	/**
	 * Y position of the mouse on the screen.
	 */
	public var mouseY(get, null):Int;
	inline function get_mouseY():Int return Std.int((HXP.app.getMouseY() - y) / scaleY);

	/**
	 * Captures the current screen as an Image object.
	 * @return	A new Image object.
	 */
	public function capture():Image
	{
		throw "Screen.capture not currently supported";
	}
}
	 * @since	2.6.0
 */
class FixedScaleMode extends ScaleMode
{
	public function new()
	{
		super(false);
	}

	override public function resize(stageWidth:Int, stageHeight:Int)
	{
		HXP.screen.width = stageWidth;
		HXP.screen.height = stageHeight;
		HXP.screen.scaleX = HXP.screen.scaleY = 1;
	}
}
	class StaticCamera extends Camera
{
	override public function update()
	{
		super.update();
		x = y = z = 0;
	}
}
