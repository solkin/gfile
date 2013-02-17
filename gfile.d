pragma(lib, "gtkd-2"); // let ld find it in your path
pragma(lib, "dl");   // gtkd depends on dl, so link it after

import gtk.MainWindow;
import gtk.Window;
import gtk.Dialog;
import gtk.AboutDialog;
import gtk.Label;
import gtk.Button;
import gtk.CheckButton;
import gtk.Box;
import gtk.VBox;
import gtk.Table;
import gtk.Main;
import gtk.Toolbar;
import gtk.ToolButton;
import gtk.Notebook;
import gtk.ListStore;
import gtk.TreeView;
import gtk.CellRenderer;
import gtk.CellRendererText;
import gtk.CellRendererProgress;
import gtk.ScrolledWindow;
import gtk.TreeViewColumn;
import gtk.TreeIter;
import gtk.Menu;
import gtk.MenuItem;
import gtk.MenuToolButton;
import gtk.SeparatorToolItem;
import gtk.FileChooserDialog;
import gtk.Entry;
import gtk.Frame;
import gtk.SpinButton;
import gobject.Type;
import std.format;
import std.string;
import std.conv;
import std.path;
import std.stdio;
import std.file;
private import stdlib = core.stdc.stdlib : exit;

class GFile : MainWindow
{
	
	Transaction[string] transactions;
	Label StatusLbl;
	Toolbar toolbar;
	TreeView transfers;
	ListStore listStore;
	
	this()
	{
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
		
		Menu menu = new Menu();
		MenuItem host_menu_item = new MenuItem(&onHost, "Host");
		menu.add(host_menu_item);
		MenuItem connect_menu_item = new MenuItem(&onConnect, "Connect");
		menu.add(connect_menu_item);
		menu.showAll();
		/** Connect button **/
        MenuToolButton connect_button = new MenuToolButton (StockID.CONNECT);
        connect_button.setMenu(menu);
        toolbar.add (connect_button);
        
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
		GType[] model = [GType.STRING, GType.STRING, GType.STRING, GType.INT, GType.STRING, GType.STRING];
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
		new Host();
	}
    
    public void onConnect(MenuItem menuItem) {
		
	}
	
	public void onFile(ToolButton toolButton) {
		FileChooserDialog fileChooser = new FileChooserDialog (
			"Open File", this, FileChooserAction.OPEN,
			["Open", "Cancel"],
			[ResponseType.ACCEPT, ResponseType.CANCEL]);
		if (fileChooser.run () == -3) {
			string filePath = fileChooser.getFilename ();
			File file = File(filePath, "r");
			// Adding transaction
			Transaction transaction = new Transaction(listStore, filePath, file.size());
			appendTransaction(transaction);
		}
		fileChooser.destroy();
	}
	
	public void onDelete(ToolButton toolButton) {
		Transaction transaction = getSelectedTransaction();
		if(transaction !is null) {
			removeTransaction(transaction);
		}
	}
	
	public void onPreferences(ToolButton toolButton) {
		new Preferences();
	}
	
	public Transaction getSelectedTransaction() {
		TreeIter iter = transfers.getSelectedIter();
		if(iter !is null) {
			string filePath = listStore.getValue(iter, 4).getString();
			return transactions[filePath];
		}
		return null;
	}
	
	public void appendTransaction(Transaction transaction) {
		transactions[transaction.getPath()] = transaction;
	}
	
	public void removeTransaction(Transaction transaction) {
		transaction.remove();
		transactions.remove(transaction.getPath());
	}
}

class Transaction {
	
	private TreeIter iter;
	private ListStore listStore;
	private string filePath;
	private string fileName;
	private long fileSize;
	private int percent;
	
	this(ListStore listStore, string filePath, long fileSize) {
		iter = new TreeIter();
		this.listStore = listStore;
		
		listStore.append (iter);
		
		this.filePath = filePath;
		this.fileName = baseName(filePath);
		this.fileSize = fileSize;
		
		updateIter();
	}
	
	public string getPath() {
		return filePath;
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
	}
}

string bytesizeToString(long bytes) {
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

class Host : Window
{
	
	this()
	{
		super("Host");
		setDefaultSize(320, 240);
		showAll();
	}
}

class Preferences : Window
{
	private SpinButton bufferSize;
	private SpinButton portNumber;
	private Entry pathEntry;
	private Entry prefixEntry;
	private CheckButton md5Check;
	
	this()
	{
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

void main(string[] args)
{
	Main.init(args);
	new GFile();
	Main.run();
}
