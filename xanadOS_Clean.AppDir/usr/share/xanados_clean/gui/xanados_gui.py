#!/usr/bin/env python3
"""
xanadOS Clean GUI - Graphical interface for Arch Linux system maintenance
Author: GitHub Copilot
Version: 2.0.0
"""

import tkinter as tk
from tkinter import ttk, scrolledtext, messagebox, filedialog
import subprocess
import threading
import queue
import os
import sys
from pathlib import Path

class XanadosGUI:
    def __init__(self, root):
        self.root = root
        self.root.title("xanadOS Clean - Arch Linux Maintenance")
        self.root.geometry("800x600")
        self.root.minsize(600, 500)
        
        # Configure style
        style = ttk.Style()
        style.theme_use('clam')
        
        # Find script path
        script_path_env = os.environ.get('XANADOS_SCRIPT_PATH')
        if script_path_env:
            self.script_path = Path(script_path_env)
        elif getattr(sys, 'frozen', False):
            # Running as AppImage
            self.script_path = Path(sys._MEIPASS) / "xanados_clean.sh"
        else:
            # Running as script
            self.script_path = Path(__file__).parent.parent / "xanados_clean.sh"
        
        # Queue for thread communication
        self.output_queue = queue.Queue()
        self.running_process = None
        
        self.setup_ui()
        self.check_script_exists()
        
        # Start checking queue for output
        self.check_queue()
        
    def setup_ui(self):
        """Setup the user interface"""
        # Create main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        main_frame.rowconfigure(4, weight=1)
        
        # Title
        title_label = ttk.Label(main_frame, text="xanadOS Clean", 
                               font=('Arial', 16, 'bold'))
        title_label.grid(row=0, column=0, columnspan=3, pady=(0, 10))
        
        # Subtitle
        subtitle_label = ttk.Label(main_frame, 
                                  text="Professional Arch Linux System Maintenance",
                                  font=('Arial', 10))
        subtitle_label.grid(row=1, column=0, columnspan=3, pady=(0, 20))
        
        # Options frame
        options_frame = ttk.LabelFrame(main_frame, text="Maintenance Options", padding="10")
        options_frame.grid(row=2, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(0, 10))
        options_frame.columnconfigure(1, weight=1)
        
        # Maintenance options
        self.auto_mode = tk.BooleanVar(value=True)
        self.simple_mode = tk.BooleanVar(value=False)
        self.dry_run = tk.BooleanVar(value=True)  # Default to dry-run for safety
        self.verbose = tk.BooleanVar(value=False)
        
        ttk.Checkbutton(options_frame, text="Auto Mode (Recommended)", 
                       variable=self.auto_mode).grid(row=0, column=0, sticky=tk.W, padx=(0, 20))
        ttk.Checkbutton(options_frame, text="Simple Mode", 
                       variable=self.simple_mode).grid(row=0, column=1, sticky=tk.W)
        ttk.Checkbutton(options_frame, text="Dry Run (Preview only)", 
                       variable=self.dry_run).grid(row=1, column=0, sticky=tk.W, padx=(0, 20))
        ttk.Checkbutton(options_frame, text="Verbose Output", 
                       variable=self.verbose).grid(row=1, column=1, sticky=tk.W)
        
        # Action buttons frame
        button_frame = ttk.Frame(main_frame)
        button_frame.grid(row=3, column=0, columnspan=3, pady=10)
        
        # Action buttons
        self.run_button = ttk.Button(button_frame, text="Run Maintenance", 
                                   command=self.run_maintenance, style="Accent.TButton")
        self.run_button.pack(side=tk.LEFT, padx=(0, 10))
        
        self.stop_button = ttk.Button(button_frame, text="Stop", 
                                    command=self.stop_maintenance, state=tk.DISABLED)
        self.stop_button.pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(button_frame, text="View Logs", 
                  command=self.view_logs).pack(side=tk.LEFT, padx=(0, 10))
        
        ttk.Button(button_frame, text="About", 
                  command=self.show_about).pack(side=tk.LEFT)
        
        # Output area
        output_frame = ttk.LabelFrame(main_frame, text="Output", padding="5")
        output_frame.grid(row=4, column=0, columnspan=3, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(10, 0))
        output_frame.columnconfigure(0, weight=1)
        output_frame.rowconfigure(0, weight=1)
        
        self.output_text = scrolledtext.ScrolledText(output_frame, height=15, 
                                                   font=('Consolas', 9))
        self.output_text.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Progress bar
        self.progress = ttk.Progressbar(main_frame, mode='indeterminate')
        self.progress.grid(row=5, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(5, 0))
        
    def check_script_exists(self):
        """Check if the maintenance script exists"""
        if not self.script_path.exists():
            self.output_text.insert(tk.END, f"Warning: Script not found at {self.script_path}\n")
            self.output_text.insert(tk.END, "Please make sure xanados_clean.sh is in the correct location.\n\n")
            self.run_button.config(state=tk.DISABLED)
        else:
            self.output_text.insert(tk.END, f"Found maintenance script at {self.script_path}\n")
            self.output_text.insert(tk.END, "Ready to run system maintenance.\n\n")
    
    def build_command(self):
        """Build the command to execute"""
        cmd = [str(self.script_path)]
        
        if self.auto_mode.get():
            cmd.append("--auto")
        if self.simple_mode.get():
            cmd.append("--simple")
        if self.dry_run.get():
            cmd.append("--dry-run")
        if self.verbose.get():
            cmd.append("--verbose")
            
        return cmd
    
    def run_maintenance(self):
        """Run the maintenance script in a separate thread"""
        if not self.script_path.exists():
            messagebox.showerror("Error", "Maintenance script not found!")
            return
            
        # Check if running as non-root user for safety
        if os.geteuid() == 0:
            if not messagebox.askyesno("Warning", 
                "Running as root user. This is potentially dangerous. Continue?"):
                return
        
        # Warn if not in dry-run mode
        if not self.dry_run.get():
            if not messagebox.askyesno("Warning", 
                "You are about to run maintenance operations that will make actual changes to your system.\n\n"
                "This may include:\n"
                "• Installing/updating packages\n"
                "• Modifying system configuration\n"
                "• Cleaning caches and logs\n\n"
                "Are you sure you want to continue?"):
                return
        
        # Disable run button and enable stop button
        self.run_button.config(state=tk.DISABLED)
        self.stop_button.config(state=tk.NORMAL)
        self.progress.start()
        
        # Clear output
        self.output_text.delete(1.0, tk.END)
        
        # Start maintenance in thread
        thread = threading.Thread(target=self.run_maintenance_thread)
        thread.daemon = True
        thread.start()
    
    def run_maintenance_thread(self):
        """Run maintenance script in a separate thread"""
        try:
            cmd = self.build_command()
            self.output_queue.put(f"Running: {' '.join(cmd)}\n\n")
            
            # Start process
            env = os.environ.copy()
            env['TERM'] = 'xterm-color'
            
            self.running_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                universal_newlines=True,
                bufsize=1,
                env=env
            )
            
            # Read output line by line
            for line in iter(self.running_process.stdout.readline, ''):
                if line:
                    self.output_queue.put(line)
            
            # Wait for process to complete
            return_code = self.running_process.wait()
            
            if return_code == 0:
                self.output_queue.put("\n✅ Maintenance completed successfully!\n")
            else:
                self.output_queue.put(f"\n❌ Maintenance failed with exit code: {return_code}\n")
                
        except Exception as e:
            self.output_queue.put(f"\n❌ Error running maintenance: {str(e)}\n")
        finally:
            self.output_queue.put("DONE")
            self.running_process = None
    
    def stop_maintenance(self):
        """Stop the running maintenance process"""
        if self.running_process:
            self.running_process.terminate()
            self.output_queue.put("\n🛑 Maintenance stopped by user.\n")
            self.output_queue.put("DONE")
    
    def check_queue(self):
        """Check the output queue for new messages"""
        try:
            while True:
                message = self.output_queue.get_nowait()
                if message == "DONE":
                    # Re-enable buttons
                    self.run_button.config(state=tk.NORMAL)
                    self.stop_button.config(state=tk.DISABLED)
                    self.progress.stop()
                    break
                else:
                    # Add message to output
                    self.output_text.insert(tk.END, message)
                    self.output_text.see(tk.END)
        except queue.Empty:
            pass
        
        # Schedule next check
        self.root.after(100, self.check_queue)
    
    def view_logs(self):
        """Open log file viewer"""
        log_file = Path.home() / "Documents" / "system_maint.log"
        if log_file.exists():
            try:
                subprocess.run(['xdg-open', str(log_file)])
            except:
                messagebox.showinfo("Log Location", f"Log file location:\n{log_file}")
        else:
            messagebox.showinfo("No Logs", "No log file found. Run maintenance first.")
    
    def show_about(self):
        """Show about dialog"""
        about_text = """xanadOS Clean v2.0.0

Professional-grade maintenance automation for Arch Linux systems.

Features:
• Smart package management with AUR support
• Intelligent mirror optimization
• Multi-backup support (Timeshift, Snapper, rsync)
• Security scanning and vulnerability assessment
• Filesystem maintenance and optimization
• System monitoring and error analysis

For more information, visit:
https://github.com/asafelobotomy/xanados_clean

License: GPL-3.0"""
        
        messagebox.showinfo("About xanadOS Clean", about_text)

def main():
    """Main application entry point"""
    root = tk.Tk()
    app = XanadosGUI(root)
    
    # Handle window closing
    def on_closing():
        if app.running_process:
            if messagebox.askokcancel("Quit", "Maintenance is running. Do you want to stop it and quit?"):
                app.stop_maintenance()
                root.destroy()
        else:
            root.destroy()
    
    root.protocol("WM_DELETE_WINDOW", on_closing)
    root.mainloop()

if __name__ == "__main__":
    main()
