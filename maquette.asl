state("Maquette"){ }

startup
{
    vars._globalTarget = new SigScanTarget("48 B8 ?? ?? ?? ?? ?? ?? ?? ?? 48 8B 08 33 D2 49 BB ?? ?? ?? ?? ?? ?? ?? ?? 41 FF D3 85 C0 74 29");
    /*
    _global:Awake+f - 48 B8 006BD16468010000 - mov rax,0000016864D16B00
    _global:Awake+19- 48 8B 08              - mov rcx,[rax]
    _global:Awake+1c- 33 D2                 - xor edx,edx
    _global:Awake+1e- 49 BB 10F9F17468010000 - mov r11,UnityEngine:Object:op_Inequality
    _global:Awake+28- 41 FF D3              - call r11
    _global:Awake+2b- 85 C0                 - test eax,eax
    _global:Awake+2d- 74 29                 - je _global:Awake+58
    */
    vars.scanCooldown = new Stopwatch();

    if (timer.CurrentTimingMethod == TimingMethod.RealTime) {        
    	var timingMessage = MessageBox.Show (
       		"This game uses Game Time (IGT) as the main timing method.\n"+
    		"LiveSplit is currently set to show Real Time (RTA).\n"+
    		"Would you like to set the timing method to IGT?",
       		"Maquette | LiveSplit",
       		MessageBoxButtons.YesNo,MessageBoxIcon.Question
       	);
        if (timingMessage == DialogResult.Yes) {
		    timer.CurrentTimingMethod = TimingMethod.GameTime;
        }
	}
    
    settings.Add("ilMode", false, "IL Mode (auto start on every level)");

    vars.waitForPlayerEnable = false;
    vars.startOnPlayerEnable = false;
}


init
{
    var _globalInstancePtr = IntPtr.Zero;
    //26861568
    //[16600] Version: 1036288 <- Chapter Select Patch


    



    if(!vars.scanCooldown.IsRunning)
    {
        vars.scanCooldown.Start(); 
    }

     if(vars.scanCooldown.Elapsed.TotalMilliseconds >= 1000) 
    {
        print("scanning");
        foreach (var page in game.MemoryPages(true))
        {
            var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
            _globalInstancePtr = scanner.Scan(vars._globalTarget);
            if(_globalInstancePtr != IntPtr.Zero)
                break;
        }

        if(_globalInstancePtr == IntPtr.Zero) 
        {
            vars.scanCooldown.Restart();
            throw new Exception("pointers not found - resetting");
        }
        else 
        {
            vars.scanCooldown.Reset();
        }
    }
    else 
    {
        throw new Exception("init not ready");
    }
    //_global.g + 0x100 -> SceneLoading

    string dll_path = modules.First().FileName + "\\..\\Maquette_Data\\Managed\\Assembly-CSharp.dll";
	long dll_size = new System.IO.FileInfo(dll_path).Length;
	print("Version: " + dll_size.ToString());
    version = dll_size.ToString();

    int playerEnableOffset = 0x0;
    switch(dll_size)
    {
        case 1036288:
            playerEnableOffset = 0x8;
            break;
        default: //1016320 is release version
            playerEnableOffset = 0x0;
            break;
    }

    var loadedSceneDP = new DeepPointer(_globalInstancePtr+0x2, 0x0, 0x100, 0x78, 0x14);
    var fadeDoneDP = new DeepPointer(_globalInstancePtr+0x2, 0x0, 0x100, 0xA0);
    var loadProgressDP = new DeepPointer(_globalInstancePtr+0x2, 0x0, 0x100, 0x9C);
    /* Original release
    var playerEnabledDP = new DeepPointer(_globalInstancePtr+0x2, 0x30); */
    var playerEnabledDP = new DeepPointer(_globalInstancePtr+0x2, 0x30 + playerEnableOffset);

    vars.loadedScene = new StringWatcher(loadedSceneDP, 250);
    vars.loadFadeDone = new MemoryWatcher<bool>(fadeDoneDP);
    vars.playerEnabled = new MemoryWatcher<bool>(playerEnabledDP);
    vars.loadProgress = new MemoryWatcher<float>(loadProgressDP);
    
    vars.watchers = new MemoryWatcherList() {vars.loadedScene, vars.loadFadeDone, vars.playerEnabled, vars.loadProgress};
}

update
{
    vars.watchers.UpdateAll(game);

    if(!vars.loadFadeDone.Current)
    {
        vars.waitForPlayerEnable = true;
    }

    if(vars.waitForPlayerEnable && vars.playerEnabled.Current)
    {
        vars.waitForPlayerEnable = false;
    }
}

isLoading
{
    return vars.waitForPlayerEnable;
}

start
{
    if((vars.loadedScene.Current == "Chapter_0" || settings["ilMode"]) && !vars.loadFadeDone.Current)
        vars.startOnPlayerEnable = true;

    if(vars.startOnPlayerEnable && vars.playerEnabled.Current)
    {
        vars.startOnPlayerEnable = false;
        return true;
    } 
}

split
{
    if(vars.loadedScene.Current != vars.loadedScene.Old && vars.loadedScene.Current != "Title" && vars.loadedScene.Old != "Title")
        return true;

    if(vars.loadedScene.Old == "Chapter_6" && vars.loadedScene.Current == "Title")
        return true;
}
