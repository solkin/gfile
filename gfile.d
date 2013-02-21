pragma(lib, "gtkd-2"); // let ld find it in your path
pragma(lib, "dl");   // gtkd depends on dl, so link it after

import gtk.MainWindow, gtk.Window, gtk.Dialog, gtk.AboutDialog,
    gtk.Label, gtk.Button, gtk.CheckButton, gtk.Box, gtk.VBox,
    gtk.Table, gtk.Main, gtk.Toolbar, gtk.ToolButton, gtk.Notebook,
    gtk.ListStore, gtk.TreeView, gtk.CellRenderer, gtk.CellRendererText,
    gtk.CellRendererProgress, gtk.ScrolledWindow, gtk.TreeViewColumn,
    gtk.TreeIter, gtk.Menu, gtk.MenuItem, gtk.MenuToolButton,
    gtk.SeparatorToolItem, gtk.FileChooserDialog, gtk.Entry, gtk.Frame,
    gtk.SpinButton, gtk.Spinner;
import gobject.Type;
import std.format;
import std.string;
import std.conv;
import std.path;
import std.stdio;
import std.file;
import std.socket;
import std.socketstream;
import std.json;
import std.parallelism;
import std.algorithm;
import std.digest.md;
import core.thread;
import core.sync.semaphore;
private import stdlib = core.stdc.stdlib : exit;

__gshared Socket mainSocket = null;
__gshared Socket dataSocket = null;
__gshared SocketStream mainStream = null;
__gshared SocketStream dataStream = null;
__gshared string host = "localhost";
__gshared ushort port = 3216;
__gshared string incomingFolder = "~/";

class GFile : MainWindow {
    
    Menu menu;
    MenuToolButton connectButton;
    Transaction[string] transactions;
    Label StatusLbl;
    Toolbar toolbar;
    TreeView transfers;
    ListStore listStore;
    bool connected;
    // Outgoing
    string[] queue;
	Semaphore queueSemaphore;
    
    this() {
        super("GFile");
        setDefaultSize(400, 300);
        Box box = new Box(Orientation.VERTICAL, 0);
        
        setupToolbar();
        setupTreeView ();
        
        ScrolledWindow scroll = new ScrolledWindow (null, null);
        scroll.setPolicy (PolicyType.AUTOMATIC, PolicyType.AUTOMATIC);
        scroll.add (transfers);
        
        Notebook notebook = new Notebook();
        box.packStart (toolbar, false, true, 0);
        box.packStart (notebook, true, true, 0);
        notebook.appendPage(scroll, new Label("Transfers"));
        
        add(box);
        showAll();  
    }
    
    private void setupToolbar() {
        toolbar = new Toolbar();
        toolbar.getStyleContext().addClass("primary-toolbar");
        
        connected = false;
        menu = new Menu();
        MenuItem host_menu_item = new MenuItem(&onHost, "Host");
        menu.add(host_menu_item);
        MenuItem connect_menu_item = new MenuItem(&onConnect, "Connect");
        menu.add(connect_menu_item);
        menu.showAll();
        /** Connect button **/
        connectButton = new MenuToolButton (StockID.CONNECT);
        connectButton.addOnClicked(&onConnectButton);
        connectButton.setMenu(menu);
        toolbar.add (connectButton);
        
        ToolButton infoButton = new ToolButton(StockID.INFO);
        toolbar.add(infoButton);
        
        toolbar.add(new SeparatorToolItem());
         
        ToolButton fileButton = new ToolButton(StockID.FILE);
        fileButton.addOnClicked(&onFile);
        toolbar.add(fileButton);
        
        ToolButton deleteButton = new ToolButton(StockID.DELETE);
        deleteButton.addOnClicked(&onDelete);
        toolbar.add(deleteButton);
        
        toolbar.add(new SeparatorToolItem());
        
        ToolButton preferencesButton = new ToolButton(StockID.PREFERENCES);
        preferencesButton.addOnClicked(&onPreferences);
        toolbar.add(preferencesButton);
    }
    
    private void setupTreeView () {
        // File name
        // File size
        // File percent (text)
        // File percent (value)
        // File path (hidden)
        // File size in bytes (hidden)
        // File MD5
        GType[] model = [GType.STRING, GType.STRING, GType.STRING, GType.INT, GType.STRING, GType.STRING, GType.STRING];
        // Model
        listStore = new ListStore (model);
        // View
        transfers = new TreeView (listStore);
        // File
        CellRenderer fileCell = new CellRendererText ();
        TreeViewColumn column = new TreeViewColumn ();
        column.setTitle ("File");
        column.packStart (fileCell, false);
        column.addAttribute (fileCell, "text", 0);
        transfers.appendColumn (column);
        // Size
        CellRenderer sizeCell = new CellRendererText ();
        column = new TreeViewColumn ();
        column.setTitle ("Size");
        column.packStart (sizeCell, false);
        column.addAttribute (sizeCell, "text", 1);
        transfers.appendColumn (column);
        // Progress
        CellRendererProgress progressCell = new CellRendererProgress ();
        column = new TreeViewColumn ();
        column.setTitle ("Progress");
        column.packStart (progressCell, false);
        column.addAttribute (progressCell, "text", 2);
        column.addAttribute (progressCell, "value", 3);
        transfers.appendColumn (column);
    }
    
    public void onHost(MenuItem menuItem) {
        (new Thread(&onHostStart)).start();
    }
    
    public void onConnect(MenuItem menuItem) {
        (new Thread(&onClientStart)).start();
    }
    
    public void onConnectButton(ToolButton toolButton) {
        if(connected) {
            disconnect();
        } else {
            (new Thread(&onClientStart)).start();
        }
    }
    
    public void afterConnection() {
        connectButton.setStockId("gtk-disconnect");
        connectButton.setMenu(null);
        connected = true;
    }
    
    public void afterDisconnection() {
        connectButton.setStockId("gtk-connect");
        connectButton.setMenu(menu);
        connected = false;
    }
    
    public void onFile(ToolButton toolButton) {
        FileChooserDialog fileChooser = new FileChooserDialog (
            "Open File", this, FileChooserAction.OPEN,
            ["Open", "Cancel"],
            [ResponseType.ACCEPT, ResponseType.CANCEL]);
        if (fileChooser.run () == -3) {
            string filePath = fileChooser.getFilename ();
            File file = File(filePath, "r");
            ulong fileSize = file.size();
            string fileMd5 = checkMd5(file);
            file.close();
            // Adding transaction
            Transaction transaction = new Transaction(listStore, filePath, fileSize, fileMd5);
            appendTransaction(transaction, true);
        }
        fileChooser.destroy();
    }
    
    public void onDelete(ToolButton toolButton) {
        Transaction transaction = getSelectedTransaction();
        if(transaction !is null) {
            removeTransaction(transaction, true);
        }
    }
    
    public void onPreferences(ToolButton toolButton) {
        // new Preferences();
        /*JSONValue json1 = void;
        json1.type = JSON_TYPE.STRING;
        json1.str = "value";
        JSONValue json0 = void;
        json0.type = JSON_TYPE.OBJECT;
        json0.str = "strrrr";
        json0.object["fttt"] = json1;
        writeln(toJSON(&json1));*/
        /*JSONValue json = parseJSON(q"EOS
{
        "key" :
        {
                "subkey1" : "str_val",
                "subkey2" : [1,2,3],
                "subkey3" : 3.1415
        }
}
EOS");
        writeln(json.object["key"].object["subkey1"].str);
        
writeln(json.object["key"].object["subkey2"].array[1].integer);
        writeln(json.object["key"].object["subkey3"].type == 
JSON_TYPE.FLOAT);*/
		string fileName = "file.txt";
		ulong fileSize = 1000000;
		string fileMd5 = "md5md5md5";
		parseLine("{\"type\" : \"file\", \"action\" : \"append\", \"name\" : \"" 
			~ fileName ~ "\", \"size\" : " ~ to!string(fileSize) 
			~ ", \"md5\" : \"" ~ fileMd5 ~ "\"}");
        // sendPacket("{\"type : \"hello\", \"client : \"gfile\", \"protocol\" : \"1.0\"}");
    }
    
    public Transaction getSelectedTransaction() {
        TreeIter iter = transfers.getSelectedIter();
        if(iter !is null) {
            string fileMd5 = listStore.getValue(iter, 6).getString();
            return transactions[fileMd5];
        }
        return null;
    }
    
    public void appendTransaction(Transaction transaction, 
        bool isSendRequest) {
        transactions[transaction.getMd5()] = transaction;
        if(isSendRequest) {
            sendAppendFile(transaction.getName(), transaction.getSize(),
				transaction.getMd5());
        }
    }
    
    public void removeTransaction(Transaction transaction,
        bool isSendRequest) {
        transaction.remove();
        transactions.remove(transaction.getMd5());
        if(isSendRequest) {
            sendRemoveFile(transaction.getName(), transaction.getSize(),
				transaction.getMd5());
        }
    }
    
    private void startStreams() {
        (new Thread(&onParserStart)).start();
        (new Thread(&onSenderStart)).start();
    }
    
    private void disconnect() {
		mainSocket.shutdown(SocketShutdown.BOTH);
		mainSocket.close();
		stopSender();
	}
    
    private void onClientStart() {
        writeln("Connecting...");
		mainSocket = new TcpSocket(new InternetAddress(host, port));
		writeln("Connected.");
		mainStream = new SocketStream(mainSocket);
        afterConnection();
        startStreams();
        // sendHello();
    }
    
    private void onHostStart() {
        TcpSocket listener = new TcpSocket();
		assert(listener.isAlive);
		listener.bind(new InternetAddress(port));
		listener.listen(2);
		writeln("Waiting for connection...");
        mainSocket = listener.accept();
		writeln("Connected: " ~ to!string(mainSocket.remoteAddress()));
		mainStream = new SocketStream(mainSocket);
        afterConnection();
        startStreams();
        // sendHello();
    }
    
    private void onParserStart() {
        string line;
        ulong length;
        try { 
            while(mainStream.isOpen()) {
                mainStream.read(length);
                line = to!string(mainStream.readString(length));
                writeln("Received: " ~ line);
                parseLine(line);
            }
        } catch (std.stream.ReadException e) {
            writeln("Error in parser");
        }
        writeln("Parser finished");
        stopSender();
    }
	
	public void sendPacket(string packet) {
		queue ~= packet;
		queueSemaphore.notify();
	}
    
    private void initSender() {
        queue = new string[0];
        if(queueSemaphore is null) {
            queueSemaphore = new Semaphore(1);
        }
    }
    
    private void stopSender() {
		connected = false;
        queueSemaphore.notify();
    }
    
    private void onSenderStart() {
        initSender();
        ulong length;
        string line;
        try {
            while(mainStream.isOpen() && connected) {
                if(queue.length > 0) {
                    line = queue[0];
                    length = line.length;
                    queue = queue[1..$];
                    writeln("Sending: " ~ line);
                    mainStream.write(length);
                    mainStream.writeString(line);
                } else {
                    queueSemaphore.wait();
                }
            }
        } catch(std.stream.WriteException e) {
            writeln("Error in sender");
        }
        writeln("Sender finished");
        connected = false;
        afterDisconnection();
    }
    
    public void parseLine(string line) {
		writeln("Parse: " ~ line);
		JSONValue json = parseJSON(line);
		string type = json["type"].str;
		writeln("Type: " ~ type);
		switch(type) {
			case "file": {
				string action = json["action"].str;
                string md5 = json["md5"].str;
				switch(action) {
					case "append": {
                        string name = json["name"].str;
                        ulong size = json["size"].uinteger;
						Transaction transaction = new Transaction(
							listStore, incomingFolder, name, size, md5);
						writeln("File accepted: " ~ name ~ " size: " ~ to!string(size));
						appendTransaction(transaction, false);
						break;
					}
                    case "remove": {
                        Transaction transaction = transactions[md5];
                        if(transaction !is null) {
                            writeln("File removed: " 
                                ~ transaction.getName() 
                                ~ " size: " 
                                ~ to!string(transaction.getSize()));
                            removeTransaction(transaction, false);
                        } else {
                            writeln("No file with MD5: " ~ md5);
                        }
                        break;
                    }
					default: {
						writeln("Unknown file operation");
					}
				}
				break;
			}
			default: {
				writeln("Unknown packet type: " ~ type);
			}
		}
	}
    
    public void sendHello() {
        sendPacket("{\"type\" : \"hello\", \"client\" : \"gfile\", \"protocol\" : \"1.0\"}");
    }
    
    public void sendAppendFile(string fileName, ulong fileSize, string fileMd5) {
        sendPacket("{\"type\" : \"file\", \"action\" : \"append\", \"name\" : \"" 
			~ fileName ~ "\", \"size\" : " ~ to!string(fileSize) 
			~ ", \"md5\" : \"" ~ fileMd5 ~ "\"}");
    }
    
    public void sendRemoveFile(string fileName, ulong fileSize, string fileMd5) {
        sendPacket("{\"type\" : \"file\", \"action\" : \"remove\", \"name\" : \"" 
            ~ fileName ~ "\", \"size\" : " ~ to!string(fileSize) 
            ~ ", \"md5\" : \"" ~ fileMd5 ~ "\"}");
    }
}

class Transaction {
    
    private TreeIter iter;
    private ListStore listStore;
    private string filePath;
    private string fileName;
    private ulong fileSize;
    private string fileMd5;
    private int percent;
    
    this(ListStore listStore, string fileDir, string fileName, 
			ulong fileSize, string fileMd5) {
		this(listStore, buildPath(fileDir, fileName), fileSize, fileMd5);
	}
    
    this(ListStore listStore, string filePath, ulong fileSize, string fileMd5) {
        iter = new TreeIter();
        this.listStore = listStore;
        
        listStore.append (iter);
        
        this.filePath = filePath;
        this.fileName = baseName(filePath);
        this.fileSize = fileSize;
        this.fileMd5 = fileMd5;
        
        updateIter();
    }
    
    public string getPath() {
        return filePath;
    }
    
    public string getName() {
        return fileName;
    }
    
    public ulong getSize() {
        return fileSize;
    }
    
    public string getMd5() {
        return fileMd5;
    }
    
    public void remove() {
        listStore.remove(iter);
    }
    
    public void updateIterPercent() {
        listStore.setValue (iter, 3, percent);
        listStore.setValue (iter, 2, to!string(percent) ~ "%");
    }
    
    private void updateIter() {
        listStore.setValue(iter, 0, fileName);
        listStore.setValue(iter, 1, bytesizeToString(fileSize));
        listStore.setValue(iter, 2, to!string(percent) ~ "%");
        listStore.setValue(iter, 3, percent);
        listStore.setValue(iter, 4, filePath);
        listStore.setValue(iter, 5, to!string(fileSize));
        listStore.setValue(iter, 6, fileMd5);
    }
}

string bytesizeToString(ulong bytes) {
    if (bytes < 1024) {
        return to!string(bytes) ~ " bytes";
    }
    auto writer = std.array.appender!string();
    if (bytes < 1024 * 1024) {
        formattedWrite(writer, "%.1f KiB", cast(double)(bytes) / 1024);
    } else if (bytes < 1024 * 1024 * 1024) {
        formattedWrite(writer, "%.1f MiB", cast(double)(bytes) / (1024 * 1024));
    } else {
        formattedWrite(writer, "%.1f GiB", cast(double)(bytes) / (1024 * 1024 * 1024));
    }
    return writer.data;
}

string checkMd5(File file) {
    MD5 md5;
    md5.start();
    int blockSize = 1024*1024;
    foreach (ubyte[] block; file.byChunk(blockSize)) {
        md5.put(block);
    }
    string md5str = toHexString(md5.finish());
    return md5str.toLower();
}

class Preferences : Window {
    private SpinButton bufferSize;
    private SpinButton portNumber;
    private Entry pathEntry;
    private Entry prefixEntry;
    private CheckButton md5Check;
    
    this() {
        super("Preferences");
        setDefaultSize(320, 240);
        
        bufferSize = new SpinButton(1, 1024*1024*1024, 1);
        portNumber = new SpinButton(1, 9999, 1);
        pathEntry = new Entry();
        prefixEntry = new Entry();
        md5Check = new CheckButton("MD5 check");
        
        Box box = new Box(Orientation.VERTICAL, 0);
        Frame frame = new Frame("Network");
        Table table = new Table(2, 2, true);
        table.attach(new Label("Buffer size (bytes):"));
        table.attach(bufferSize);
        table.attach(new Label("Port:"));
        table.attach(portNumber);
        frame.add(table);
        box.add(frame);
        Frame frame1 = new Frame("Local");
        Table table1 = new Table(3, 2, true);
        table1.attach(new Label("Path to save:"));
        table1.attach(pathEntry);
        table1.attach(new Label("Prefix for received files:"));
        table1.attach(prefixEntry);
        table1.attach(md5Check);
        frame1.add(table1);
        box.add(frame1);
        box.add(new Button("OK", &onOk));
        box.add(new Button("Cancel", &onCancel));
        add(box);
        
        // Path to save
        // Port
        // MD5 check
        // Buffer size
        // Prefix for received files
        
        showAll();
    }
    
    public void onOk(Button button) {
        destroy();
    }
    
    public void onCancel(Button button) {
        destroy();
    }
}

void main(string[] args) {
    Main.init(args);
    new GFile();
    Main.run();
}
