/*
 *  Copyright (C) 2003-2007 Gurock Software GmbH. All rights reserved.
 *
 *  Description:
 *
 *  This example demonstrates the most used features of the 
 *  SmartInspect .NET library. Each page features another part of 
 *  the SmartInspect .NET library functionality.
 *
 */
 
using System;
using System.Drawing;
using System.Collections;
using System.ComponentModel;
using System.Windows.Forms;
using System.Data;
using System.IO;
using Gurock.SmartInspect;

namespace Gurock.SmartInspct.Examples.Advanced
{
	/// <summary>
	/// Summary description for Form1.
	/// </summary>
	public class MainForm : System.Windows.Forms.Form
	{
		private System.Windows.Forms.Label infoLabel;
		private System.Windows.Forms.Label advancedLabel;
		private System.Windows.Forms.Button closeButton;
		private System.Windows.Forms.TabPage infoPage;
		private System.Windows.Forms.TabControl tabControl;
		private System.Windows.Forms.TabPage generalPage;
		private System.Windows.Forms.Label messageLabel;
		private System.Windows.Forms.TextBox messageTextBox;
		private System.Windows.Forms.Button messageButton;
		private System.Windows.Forms.Label warningLabel;
		private System.Windows.Forms.TextBox warningTextBox;
		private System.Windows.Forms.Button warningButton;
		private System.Windows.Forms.TextBox failureTextBox;
		private System.Windows.Forms.Label errorLabel;
		private System.Windows.Forms.TextBox errorTextBox;
		private System.Windows.Forms.Button errorButton;
		private System.Windows.Forms.Label enterMethodLabel;
		private System.Windows.Forms.TextBox enterMethodTextBox;
		private System.Windows.Forms.Button enterMethodButton;
		private System.Windows.Forms.Label leaveMethodLabel;
		private System.Windows.Forms.Button leaveMethodButton;
		private System.Windows.Forms.TextBox leaveMethodTextBox;
		private System.Windows.Forms.Button separatorButton;
		private System.Windows.Forms.Button addCheckpointButton;
		private System.Windows.Forms.Button resetCheckpointButton;
		private System.Windows.Forms.Button exceptionButton;
		private System.Windows.Forms.TabPage valuesPage;
		private System.Windows.Forms.Label stringLabel;
		private System.Windows.Forms.TextBox stringTextBox;
		private System.Windows.Forms.Button stringLogButton;
		private System.Windows.Forms.Button stringWatchButton;
		private System.Windows.Forms.Label charLabel;
		private System.Windows.Forms.TextBox charTextBox;
		private System.Windows.Forms.Button charLogButton;
		private System.Windows.Forms.Button charWatchButton;
		private System.Windows.Forms.Label valuesLabel;
		private System.Windows.Forms.Label integerLabel;
		private System.Windows.Forms.TextBox integerTextBox;
		private System.Windows.Forms.Button integerLogButton;
		private System.Windows.Forms.Button integerWatchButton;
		private System.Windows.Forms.Label doubleLabel;
		private System.Windows.Forms.TextBox doubleTextBox;
		private System.Windows.Forms.Button doubleLogButton;
		private System.Windows.Forms.Button doubleWatchButton;
		private System.Windows.Forms.TabPage sourcePage;
		private System.Windows.Forms.Label sourceLabel;
		private System.Windows.Forms.ComboBox sourceComboBox;
		private System.Windows.Forms.Button sourceButton;
		private System.Windows.Forms.TextBox sourceTextBox;
		private System.Windows.Forms.TabPage picturePage;
		private System.Windows.Forms.TabPage miscPage;
		private System.Windows.Forms.Label objectLabel;
		private System.Windows.Forms.Button objectButton;
		private System.Windows.Forms.Label systemLabel;
		private System.Windows.Forms.Button systemButton;
		private System.Windows.Forms.PictureBox pictureBox;
		private System.Windows.Forms.Button pictureButton;
		/// <summary>
		/// Required designer variable.
		/// </summary>
		private System.ComponentModel.Container components = null;

		public MainForm()
		{
			//
			// Required for Windows Form Designer support
			//
			InitializeComponent();

			//
			// TODO: Add any constructor code after InitializeComponent call
			//
		}

		/// <summary>
		/// Clean up any resources being used.
		/// </summary>
		protected override void Dispose( bool disposing )
		{
			if( disposing )
			{
				if (components != null) 
				{
					components.Dispose();
				}
			}
			base.Dispose( disposing );
		}

		#region Windows Form Designer generated code
		/// <summary>
		/// Required method for Designer support - do not modify
		/// the contents of this method with the code editor.
		/// </summary>
		private void InitializeComponent()
		{
			this.tabControl = new System.Windows.Forms.TabControl();
			this.infoPage = new System.Windows.Forms.TabPage();
			this.failureTextBox = new System.Windows.Forms.TextBox();
			this.advancedLabel = new System.Windows.Forms.Label();
			this.infoLabel = new System.Windows.Forms.Label();
			this.generalPage = new System.Windows.Forms.TabPage();
			this.exceptionButton = new System.Windows.Forms.Button();
			this.resetCheckpointButton = new System.Windows.Forms.Button();
			this.addCheckpointButton = new System.Windows.Forms.Button();
			this.separatorButton = new System.Windows.Forms.Button();
			this.leaveMethodButton = new System.Windows.Forms.Button();
			this.leaveMethodTextBox = new System.Windows.Forms.TextBox();
			this.leaveMethodLabel = new System.Windows.Forms.Label();
			this.enterMethodButton = new System.Windows.Forms.Button();
			this.enterMethodTextBox = new System.Windows.Forms.TextBox();
			this.enterMethodLabel = new System.Windows.Forms.Label();
			this.errorButton = new System.Windows.Forms.Button();
			this.errorTextBox = new System.Windows.Forms.TextBox();
			this.errorLabel = new System.Windows.Forms.Label();
			this.warningButton = new System.Windows.Forms.Button();
			this.warningTextBox = new System.Windows.Forms.TextBox();
			this.warningLabel = new System.Windows.Forms.Label();
			this.messageButton = new System.Windows.Forms.Button();
			this.messageTextBox = new System.Windows.Forms.TextBox();
			this.messageLabel = new System.Windows.Forms.Label();
			this.valuesPage = new System.Windows.Forms.TabPage();
			this.doubleWatchButton = new System.Windows.Forms.Button();
			this.doubleLogButton = new System.Windows.Forms.Button();
			this.doubleTextBox = new System.Windows.Forms.TextBox();
			this.doubleLabel = new System.Windows.Forms.Label();
			this.integerWatchButton = new System.Windows.Forms.Button();
			this.integerLogButton = new System.Windows.Forms.Button();
			this.integerTextBox = new System.Windows.Forms.TextBox();
			this.integerLabel = new System.Windows.Forms.Label();
			this.valuesLabel = new System.Windows.Forms.Label();
			this.charWatchButton = new System.Windows.Forms.Button();
			this.charLogButton = new System.Windows.Forms.Button();
			this.charTextBox = new System.Windows.Forms.TextBox();
			this.charLabel = new System.Windows.Forms.Label();
			this.stringWatchButton = new System.Windows.Forms.Button();
			this.stringLogButton = new System.Windows.Forms.Button();
			this.stringTextBox = new System.Windows.Forms.TextBox();
			this.stringLabel = new System.Windows.Forms.Label();
			this.sourcePage = new System.Windows.Forms.TabPage();
			this.sourceTextBox = new System.Windows.Forms.TextBox();
			this.sourceButton = new System.Windows.Forms.Button();
			this.sourceComboBox = new System.Windows.Forms.ComboBox();
			this.sourceLabel = new System.Windows.Forms.Label();
			this.picturePage = new System.Windows.Forms.TabPage();
			this.pictureButton = new System.Windows.Forms.Button();
			this.pictureBox = new System.Windows.Forms.PictureBox();
			this.miscPage = new System.Windows.Forms.TabPage();
			this.systemButton = new System.Windows.Forms.Button();
			this.systemLabel = new System.Windows.Forms.Label();
			this.objectButton = new System.Windows.Forms.Button();
			this.objectLabel = new System.Windows.Forms.Label();
			this.closeButton = new System.Windows.Forms.Button();
			this.tabControl.SuspendLayout();
			this.infoPage.SuspendLayout();
			this.generalPage.SuspendLayout();
			this.valuesPage.SuspendLayout();
			this.sourcePage.SuspendLayout();
			this.picturePage.SuspendLayout();
			this.miscPage.SuspendLayout();
			this.SuspendLayout();
			// 
			// tabControl
			// 
			this.tabControl.Controls.Add(this.infoPage);
			this.tabControl.Controls.Add(this.generalPage);
			this.tabControl.Controls.Add(this.valuesPage);
			this.tabControl.Controls.Add(this.sourcePage);
			this.tabControl.Controls.Add(this.picturePage);
			this.tabControl.Controls.Add(this.miscPage);
			this.tabControl.Location = new System.Drawing.Point(8, 8);
			this.tabControl.Name = "tabControl";
			this.tabControl.SelectedIndex = 0;
			this.tabControl.Size = new System.Drawing.Size(528, 288);
			this.tabControl.TabIndex = 0;
			// 
			// infoPage
			// 
			this.infoPage.Controls.Add(this.failureTextBox);
			this.infoPage.Controls.Add(this.advancedLabel);
			this.infoPage.Controls.Add(this.infoLabel);
			this.infoPage.Location = new System.Drawing.Point(4, 22);
			this.infoPage.Name = "infoPage";
			this.infoPage.Size = new System.Drawing.Size(520, 262);
			this.infoPage.TabIndex = 0;
			this.infoPage.Text = "Information";
			// 
			// failureTextBox
			// 
			this.failureTextBox.Location = new System.Drawing.Point(8, 152);
			this.failureTextBox.Multiline = true;
			this.failureTextBox.Name = "failureTextBox";
			this.failureTextBox.ReadOnly = true;
			this.failureTextBox.Size = new System.Drawing.Size(504, 96);
			this.failureTextBox.TabIndex = 3;
			this.failureTextBox.Text = "";
			// 
			// advancedLabel
			// 
			this.advancedLabel.Font = new System.Drawing.Font("Microsoft Sans Serif", 15.75F, System.Drawing.FontStyle.Bold, System.Drawing.GraphicsUnit.Point, ((System.Byte)(0)));
			this.advancedLabel.Location = new System.Drawing.Point(8, 24);
			this.advancedLabel.Name = "advancedLabel";
			this.advancedLabel.Size = new System.Drawing.Size(504, 23);
			this.advancedLabel.TabIndex = 1;
			this.advancedLabel.Text = "Advanced SmartInspect Example";
			// 
			// infoLabel
			// 
			this.infoLabel.Location = new System.Drawing.Point(8, 64);
			this.infoLabel.Name = "infoLabel";
			this.infoLabel.Size = new System.Drawing.Size(504, 32);
			this.infoLabel.TabIndex = 0;
			this.infoLabel.Text = "This example demonstrates the most used features of the SmartInspect library. Eac" +
				"h page features another part of the SmartInspect library functionality.";
			// 
			// generalPage
			// 
			this.generalPage.Controls.Add(this.exceptionButton);
			this.generalPage.Controls.Add(this.resetCheckpointButton);
			this.generalPage.Controls.Add(this.addCheckpointButton);
			this.generalPage.Controls.Add(this.separatorButton);
			this.generalPage.Controls.Add(this.leaveMethodButton);
			this.generalPage.Controls.Add(this.leaveMethodTextBox);
			this.generalPage.Controls.Add(this.leaveMethodLabel);
			this.generalPage.Controls.Add(this.enterMethodButton);
			this.generalPage.Controls.Add(this.enterMethodTextBox);
			this.generalPage.Controls.Add(this.enterMethodLabel);
			this.generalPage.Controls.Add(this.errorButton);
			this.generalPage.Controls.Add(this.errorTextBox);
			this.generalPage.Controls.Add(this.errorLabel);
			this.generalPage.Controls.Add(this.warningButton);
			this.generalPage.Controls.Add(this.warningTextBox);
			this.generalPage.Controls.Add(this.warningLabel);
			this.generalPage.Controls.Add(this.messageButton);
			this.generalPage.Controls.Add(this.messageTextBox);
			this.generalPage.Controls.Add(this.messageLabel);
			this.generalPage.Location = new System.Drawing.Point(4, 22);
			this.generalPage.Name = "generalPage";
			this.generalPage.Size = new System.Drawing.Size(520, 262);
			this.generalPage.TabIndex = 1;
			this.generalPage.Text = "General";
			// 
			// exceptionButton
			// 
			this.exceptionButton.Location = new System.Drawing.Point(336, 216);
			this.exceptionButton.Name = "exceptionButton";
			this.exceptionButton.Size = new System.Drawing.Size(104, 23);
			this.exceptionButton.TabIndex = 18;
			this.exceptionButton.Text = "Log Exception";
			this.exceptionButton.Click += new System.EventHandler(this.exceptionButton_Click);
			// 
			// resetCheckpointButton
			// 
			this.resetCheckpointButton.Location = new System.Drawing.Point(224, 216);
			this.resetCheckpointButton.Name = "resetCheckpointButton";
			this.resetCheckpointButton.Size = new System.Drawing.Size(104, 23);
			this.resetCheckpointButton.TabIndex = 17;
			this.resetCheckpointButton.Text = "Reset Checkpoint";
			this.resetCheckpointButton.Click += new System.EventHandler(this.resetCheckpointButton_Click);
			// 
			// addCheckpointButton
			// 
			this.addCheckpointButton.Location = new System.Drawing.Point(120, 216);
			this.addCheckpointButton.Name = "addCheckpointButton";
			this.addCheckpointButton.Size = new System.Drawing.Size(96, 23);
			this.addCheckpointButton.TabIndex = 16;
			this.addCheckpointButton.Text = "Add Checkpoint";
			this.addCheckpointButton.Click += new System.EventHandler(this.addCheckpointButton_Click);
			// 
			// separatorButton
			// 
			this.separatorButton.Location = new System.Drawing.Point(16, 216);
			this.separatorButton.Name = "separatorButton";
			this.separatorButton.Size = new System.Drawing.Size(96, 23);
			this.separatorButton.TabIndex = 15;
			this.separatorButton.Text = "Log Separator";
			this.separatorButton.Click += new System.EventHandler(this.separatorButton_Click);
			// 
			// leaveMethodButton
			// 
			this.leaveMethodButton.Location = new System.Drawing.Point(408, 165);
			this.leaveMethodButton.Name = "leaveMethodButton";
			this.leaveMethodButton.Size = new System.Drawing.Size(96, 23);
			this.leaveMethodButton.TabIndex = 14;
			this.leaveMethodButton.Text = "Leave Method";
			this.leaveMethodButton.Click += new System.EventHandler(this.leaveMethodButton_Click);
			// 
			// leaveMethodTextBox
			// 
			this.leaveMethodTextBox.Location = new System.Drawing.Point(96, 166);
			this.leaveMethodTextBox.Name = "leaveMethodTextBox";
			this.leaveMethodTextBox.Size = new System.Drawing.Size(304, 20);
			this.leaveMethodTextBox.TabIndex = 13;
			this.leaveMethodTextBox.Text = "Button1Click";
			// 
			// leaveMethodLabel
			// 
			this.leaveMethodLabel.Location = new System.Drawing.Point(16, 168);
			this.leaveMethodLabel.Name = "leaveMethodLabel";
			this.leaveMethodLabel.Size = new System.Drawing.Size(80, 16);
			this.leaveMethodLabel.TabIndex = 12;
			this.leaveMethodLabel.Text = "Leave Method:";
			// 
			// enterMethodButton
			// 
			this.enterMethodButton.Location = new System.Drawing.Point(408, 135);
			this.enterMethodButton.Name = "enterMethodButton";
			this.enterMethodButton.Size = new System.Drawing.Size(96, 23);
			this.enterMethodButton.TabIndex = 11;
			this.enterMethodButton.Text = "Enter Method";
			this.enterMethodButton.Click += new System.EventHandler(this.enterMethodButton_Click);
			// 
			// enterMethodTextBox
			// 
			this.enterMethodTextBox.Location = new System.Drawing.Point(96, 136);
			this.enterMethodTextBox.Name = "enterMethodTextBox";
			this.enterMethodTextBox.Size = new System.Drawing.Size(304, 20);
			this.enterMethodTextBox.TabIndex = 10;
			this.enterMethodTextBox.Text = "Button1Click";
			// 
			// enterMethodLabel
			// 
			this.enterMethodLabel.Location = new System.Drawing.Point(16, 138);
			this.enterMethodLabel.Name = "enterMethodLabel";
			this.enterMethodLabel.Size = new System.Drawing.Size(80, 16);
			this.enterMethodLabel.TabIndex = 9;
			this.enterMethodLabel.Text = "Enter Method:";
			// 
			// errorButton
			// 
			this.errorButton.Location = new System.Drawing.Point(408, 88);
			this.errorButton.Name = "errorButton";
			this.errorButton.Size = new System.Drawing.Size(96, 23);
			this.errorButton.TabIndex = 8;
			this.errorButton.Text = "Log Error";
			this.errorButton.Click += new System.EventHandler(this.errorButton_Click);
			// 
			// errorTextBox
			// 
			this.errorTextBox.Location = new System.Drawing.Point(72, 89);
			this.errorTextBox.Name = "errorTextBox";
			this.errorTextBox.Size = new System.Drawing.Size(328, 20);
			this.errorTextBox.TabIndex = 7;
			this.errorTextBox.Text = "This is an example error.";
			// 
			// errorLabel
			// 
			this.errorLabel.Location = new System.Drawing.Point(16, 91);
			this.errorLabel.Name = "errorLabel";
			this.errorLabel.Size = new System.Drawing.Size(56, 16);
			this.errorLabel.TabIndex = 6;
			this.errorLabel.Text = "Error:";
			// 
			// warningButton
			// 
			this.warningButton.Location = new System.Drawing.Point(408, 55);
			this.warningButton.Name = "warningButton";
			this.warningButton.Size = new System.Drawing.Size(96, 23);
			this.warningButton.TabIndex = 5;
			this.warningButton.Text = "Log Warning";
			this.warningButton.Click += new System.EventHandler(this.warningButton_Click);
			// 
			// warningTextBox
			// 
			this.warningTextBox.Location = new System.Drawing.Point(72, 56);
			this.warningTextBox.Name = "warningTextBox";
			this.warningTextBox.Size = new System.Drawing.Size(328, 20);
			this.warningTextBox.TabIndex = 4;
			this.warningTextBox.Text = "This is an example warning.";
			// 
			// warningLabel
			// 
			this.warningLabel.Location = new System.Drawing.Point(16, 58);
			this.warningLabel.Name = "warningLabel";
			this.warningLabel.Size = new System.Drawing.Size(56, 17);
			this.warningLabel.TabIndex = 3;
			this.warningLabel.Text = "Warning:";
			// 
			// messageButton
			// 
			this.messageButton.Location = new System.Drawing.Point(408, 22);
			this.messageButton.Name = "messageButton";
			this.messageButton.Size = new System.Drawing.Size(96, 24);
			this.messageButton.TabIndex = 2;
			this.messageButton.Text = "Log Message";
			this.messageButton.Click += new System.EventHandler(this.messageButton_Click);
			// 
			// messageTextBox
			// 
			this.messageTextBox.Location = new System.Drawing.Point(72, 24);
			this.messageTextBox.Name = "messageTextBox";
			this.messageTextBox.Size = new System.Drawing.Size(328, 20);
			this.messageTextBox.TabIndex = 1;
			this.messageTextBox.Text = "This is an example message.";
			// 
			// messageLabel
			// 
			this.messageLabel.Location = new System.Drawing.Point(16, 28);
			this.messageLabel.Name = "messageLabel";
			this.messageLabel.Size = new System.Drawing.Size(56, 13);
			this.messageLabel.TabIndex = 0;
			this.messageLabel.Text = "Message:";
			// 
			// valuesPage
			// 
			this.valuesPage.Controls.Add(this.doubleWatchButton);
			this.valuesPage.Controls.Add(this.doubleLogButton);
			this.valuesPage.Controls.Add(this.doubleTextBox);
			this.valuesPage.Controls.Add(this.doubleLabel);
			this.valuesPage.Controls.Add(this.integerWatchButton);
			this.valuesPage.Controls.Add(this.integerLogButton);
			this.valuesPage.Controls.Add(this.integerTextBox);
			this.valuesPage.Controls.Add(this.integerLabel);
			this.valuesPage.Controls.Add(this.valuesLabel);
			this.valuesPage.Controls.Add(this.charWatchButton);
			this.valuesPage.Controls.Add(this.charLogButton);
			this.valuesPage.Controls.Add(this.charTextBox);
			this.valuesPage.Controls.Add(this.charLabel);
			this.valuesPage.Controls.Add(this.stringWatchButton);
			this.valuesPage.Controls.Add(this.stringLogButton);
			this.valuesPage.Controls.Add(this.stringTextBox);
			this.valuesPage.Controls.Add(this.stringLabel);
			this.valuesPage.Location = new System.Drawing.Point(4, 22);
			this.valuesPage.Name = "valuesPage";
			this.valuesPage.Size = new System.Drawing.Size(520, 262);
			this.valuesPage.TabIndex = 2;
			this.valuesPage.Text = "Values and Watches";
			// 
			// doubleWatchButton
			// 
			this.doubleWatchButton.Location = new System.Drawing.Point(432, 119);
			this.doubleWatchButton.Name = "doubleWatchButton";
			this.doubleWatchButton.TabIndex = 16;
			this.doubleWatchButton.Text = "Watch";
			this.doubleWatchButton.Click += new System.EventHandler(this.doubleWatchButton_Click);
			// 
			// doubleLogButton
			// 
			this.doubleLogButton.Location = new System.Drawing.Point(352, 119);
			this.doubleLogButton.Name = "doubleLogButton";
			this.doubleLogButton.TabIndex = 15;
			this.doubleLogButton.Text = "Log";
			this.doubleLogButton.Click += new System.EventHandler(this.doubleLogButton_Click);
			// 
			// doubleTextBox
			// 
			this.doubleTextBox.Location = new System.Drawing.Point(64, 120);
			this.doubleTextBox.Name = "doubleTextBox";
			this.doubleTextBox.Size = new System.Drawing.Size(280, 20);
			this.doubleTextBox.TabIndex = 14;
			this.doubleTextBox.Text = "32946.23427";
			// 
			// doubleLabel
			// 
			this.doubleLabel.Location = new System.Drawing.Point(16, 122);
			this.doubleLabel.Name = "doubleLabel";
			this.doubleLabel.Size = new System.Drawing.Size(40, 16);
			this.doubleLabel.TabIndex = 13;
			this.doubleLabel.Text = "Double:";
			// 
			// integerWatchButton
			// 
			this.integerWatchButton.Location = new System.Drawing.Point(432, 87);
			this.integerWatchButton.Name = "integerWatchButton";
			this.integerWatchButton.TabIndex = 12;
			this.integerWatchButton.Text = "Watch";
			this.integerWatchButton.Click += new System.EventHandler(this.integerWatchButton_Click);
			// 
			// integerLogButton
			// 
			this.integerLogButton.Location = new System.Drawing.Point(352, 87);
			this.integerLogButton.Name = "integerLogButton";
			this.integerLogButton.TabIndex = 11;
			this.integerLogButton.Text = "Log";
			this.integerLogButton.Click += new System.EventHandler(this.integerLogButton_Click);
			// 
			// integerTextBox
			// 
			this.integerTextBox.Location = new System.Drawing.Point(64, 88);
			this.integerTextBox.Name = "integerTextBox";
			this.integerTextBox.Size = new System.Drawing.Size(280, 20);
			this.integerTextBox.TabIndex = 10;
			this.integerTextBox.Text = "32984";
			// 
			// integerLabel
			// 
			this.integerLabel.Location = new System.Drawing.Point(16, 90);
			this.integerLabel.Name = "integerLabel";
			this.integerLabel.Size = new System.Drawing.Size(48, 16);
			this.integerLabel.TabIndex = 9;
			this.integerLabel.Text = "Integer:";
			// 
			// valuesLabel
			// 
			this.valuesLabel.Location = new System.Drawing.Point(16, 162);
			this.valuesLabel.Name = "valuesLabel";
			this.valuesLabel.Size = new System.Drawing.Size(496, 32);
			this.valuesLabel.TabIndex = 8;
			this.valuesLabel.Text = "With SmartInspect you can log values directly to the SmartInspect Console. Watche" +
				"s are displayed in the Watches toolbox and can be tracked for each log entry ind" +
				"ividually.";
			// 
			// charWatchButton
			// 
			this.charWatchButton.Location = new System.Drawing.Point(432, 55);
			this.charWatchButton.Name = "charWatchButton";
			this.charWatchButton.TabIndex = 7;
			this.charWatchButton.Text = "Watch";
			this.charWatchButton.Click += new System.EventHandler(this.charWatchButton_Click);
			// 
			// charLogButton
			// 
			this.charLogButton.Location = new System.Drawing.Point(352, 55);
			this.charLogButton.Name = "charLogButton";
			this.charLogButton.TabIndex = 6;
			this.charLogButton.Text = "Log";
			this.charLogButton.Click += new System.EventHandler(this.charLogButton_Click);
			// 
			// charTextBox
			// 
			this.charTextBox.Location = new System.Drawing.Point(64, 56);
			this.charTextBox.Name = "charTextBox";
			this.charTextBox.Size = new System.Drawing.Size(280, 20);
			this.charTextBox.TabIndex = 5;
			this.charTextBox.Text = "C";
			// 
			// charLabel
			// 
			this.charLabel.Location = new System.Drawing.Point(16, 58);
			this.charLabel.Name = "charLabel";
			this.charLabel.Size = new System.Drawing.Size(40, 16);
			this.charLabel.TabIndex = 4;
			this.charLabel.Text = "Char:";
			// 
			// stringWatchButton
			// 
			this.stringWatchButton.Location = new System.Drawing.Point(432, 23);
			this.stringWatchButton.Name = "stringWatchButton";
			this.stringWatchButton.TabIndex = 3;
			this.stringWatchButton.Text = "Watch";
			this.stringWatchButton.Click += new System.EventHandler(this.stringWatchButton_Click);
			// 
			// stringLogButton
			// 
			this.stringLogButton.Location = new System.Drawing.Point(352, 23);
			this.stringLogButton.Name = "stringLogButton";
			this.stringLogButton.TabIndex = 2;
			this.stringLogButton.Text = "Log";
			this.stringLogButton.Click += new System.EventHandler(this.stringLogButton_Click);
			// 
			// stringTextBox
			// 
			this.stringTextBox.Location = new System.Drawing.Point(64, 24);
			this.stringTextBox.Name = "stringTextBox";
			this.stringTextBox.Size = new System.Drawing.Size(280, 20);
			this.stringTextBox.TabIndex = 1;
			this.stringTextBox.Text = "Example String";
			// 
			// stringLabel
			// 
			this.stringLabel.Location = new System.Drawing.Point(16, 28);
			this.stringLabel.Name = "stringLabel";
			this.stringLabel.Size = new System.Drawing.Size(40, 14);
			this.stringLabel.TabIndex = 0;
			this.stringLabel.Text = "String:";
			// 
			// sourcePage
			// 
			this.sourcePage.Controls.Add(this.sourceTextBox);
			this.sourcePage.Controls.Add(this.sourceButton);
			this.sourcePage.Controls.Add(this.sourceComboBox);
			this.sourcePage.Controls.Add(this.sourceLabel);
			this.sourcePage.Location = new System.Drawing.Point(4, 22);
			this.sourcePage.Name = "sourcePage";
			this.sourcePage.Size = new System.Drawing.Size(520, 262);
			this.sourcePage.TabIndex = 3;
			this.sourcePage.Text = "Source";
			// 
			// sourceTextBox
			// 
			this.sourceTextBox.Location = new System.Drawing.Point(16, 56);
			this.sourceTextBox.Multiline = true;
			this.sourceTextBox.Name = "sourceTextBox";
			this.sourceTextBox.Size = new System.Drawing.Size(488, 192);
			this.sourceTextBox.TabIndex = 6;
			this.sourceTextBox.Text = "SELECT id, name FROM orders WHERE customer_id = 15";
			// 
			// sourceButton
			// 
			this.sourceButton.Location = new System.Drawing.Point(296, 20);
			this.sourceButton.Name = "sourceButton";
			this.sourceButton.Size = new System.Drawing.Size(72, 23);
			this.sourceButton.TabIndex = 5;
			this.sourceButton.Text = "Log Source";
			this.sourceButton.Click += new System.EventHandler(this.sourceButton_Click);
			// 
			// sourceComboBox
			// 
			this.sourceComboBox.DropDownStyle = System.Windows.Forms.ComboBoxStyle.DropDownList;
			this.sourceComboBox.Items.AddRange(new object[] {
																"HTML",
																"JavaScript",
																"VB Script",
																"Perl",
																"SQL",
																"INI File",
																"Python",
																"Xml"});
			this.sourceComboBox.Location = new System.Drawing.Point(104, 21);
			this.sourceComboBox.Name = "sourceComboBox";
			this.sourceComboBox.Size = new System.Drawing.Size(184, 21);
			this.sourceComboBox.TabIndex = 7;
			// 
			// sourceLabel
			// 
			this.sourceLabel.Location = new System.Drawing.Point(16, 23);
			this.sourceLabel.Name = "sourceLabel";
			this.sourceLabel.Size = new System.Drawing.Size(88, 16);
			this.sourceLabel.TabIndex = 0;
			this.sourceLabel.Text = "Source Format:";
			// 
			// picturePage
			// 
			this.picturePage.Controls.Add(this.pictureButton);
			this.picturePage.Controls.Add(this.pictureBox);
			this.picturePage.Location = new System.Drawing.Point(4, 22);
			this.picturePage.Name = "picturePage";
			this.picturePage.Size = new System.Drawing.Size(520, 262);
			this.picturePage.TabIndex = 4;
			this.picturePage.Text = "Picture";
			// 
			// pictureButton
			// 
			this.pictureButton.Location = new System.Drawing.Point(8, 232);
			this.pictureButton.Name = "pictureButton";
			this.pictureButton.TabIndex = 1;
			this.pictureButton.Text = "Log Picture";
			this.pictureButton.Click += new System.EventHandler(this.pictureButton_Click);
			// 
			// pictureBox
			// 
			this.pictureBox.Location = new System.Drawing.Point(9, 48);
			this.pictureBox.Name = "pictureBox";
			this.pictureBox.Size = new System.Drawing.Size(503, 160);
			this.pictureBox.SizeMode = System.Windows.Forms.PictureBoxSizeMode.CenterImage;
			this.pictureBox.TabIndex = 0;
			this.pictureBox.TabStop = false;
			// 
			// miscPage
			// 
			this.miscPage.Controls.Add(this.systemButton);
			this.miscPage.Controls.Add(this.systemLabel);
			this.miscPage.Controls.Add(this.objectButton);
			this.miscPage.Controls.Add(this.objectLabel);
			this.miscPage.Location = new System.Drawing.Point(4, 22);
			this.miscPage.Name = "miscPage";
			this.miscPage.Size = new System.Drawing.Size(520, 262);
			this.miscPage.TabIndex = 5;
			this.miscPage.Text = "Misc";
			// 
			// systemButton
			// 
			this.systemButton.Location = new System.Drawing.Point(384, 56);
			this.systemButton.Name = "systemButton";
			this.systemButton.Size = new System.Drawing.Size(120, 23);
			this.systemButton.TabIndex = 3;
			this.systemButton.Text = "Log System";
			this.systemButton.Click += new System.EventHandler(this.systemButton_Click);
			// 
			// systemLabel
			// 
			this.systemLabel.Location = new System.Drawing.Point(16, 56);
			this.systemLabel.Name = "systemLabel";
			this.systemLabel.Size = new System.Drawing.Size(320, 16);
			this.systemLabel.TabIndex = 2;
			this.systemLabel.Text = "Log system information such as .NET or Windows version:";
			// 
			// objectButton
			// 
			this.objectButton.Location = new System.Drawing.Point(384, 16);
			this.objectButton.Name = "objectButton";
			this.objectButton.Size = new System.Drawing.Size(120, 23);
			this.objectButton.TabIndex = 1;
			this.objectButton.Text = "Log Object";
			this.objectButton.Click += new System.EventHandler(this.objectButton_Click);
			// 
			// objectLabel
			// 
			this.objectLabel.Location = new System.Drawing.Point(16, 19);
			this.objectLabel.Name = "objectLabel";
			this.objectLabel.Size = new System.Drawing.Size(264, 16);
			this.objectLabel.TabIndex = 0;
			this.objectLabel.Text = "Log this form\'s object to the SmartInspect Console:";
			// 
			// closeButton
			// 
			this.closeButton.Location = new System.Drawing.Point(456, 304);
			this.closeButton.Name = "closeButton";
			this.closeButton.Size = new System.Drawing.Size(75, 24);
			this.closeButton.TabIndex = 1;
			this.closeButton.Text = "Close";
			this.closeButton.Click += new System.EventHandler(this.closeButton_Click);
			// 
			// MainForm
			// 
			this.AutoScaleBaseSize = new System.Drawing.Size(5, 13);
			this.ClientSize = new System.Drawing.Size(544, 336);
			this.Controls.Add(this.closeButton);
			this.Controls.Add(this.tabControl);
			this.FormBorderStyle = System.Windows.Forms.FormBorderStyle.FixedSingle;
			this.MaximizeBox = false;
			this.MinimizeBox = false;
			this.Name = "MainForm";
			this.Text = "Advanced SmartInspect Example";
			this.Load += new System.EventHandler(this.MainForm_Load);
			this.tabControl.ResumeLayout(false);
			this.infoPage.ResumeLayout(false);
			this.generalPage.ResumeLayout(false);
			this.valuesPage.ResumeLayout(false);
			this.sourcePage.ResumeLayout(false);
			this.picturePage.ResumeLayout(false);
			this.miscPage.ResumeLayout(false);
			this.ResumeLayout(false);

		}
		#endregion

		/// <summary>
		/// The main entry point for the application.
		/// </summary>
		[STAThread]
		static void Main() 
		{
			Application.Run(new MainForm());
		}

		private void HandleError(object sender, Gurock.SmartInspect.ErrorEventArgs e)
		{
			this.failureTextBox.Text = e.Exception.Message;
			this.failureTextBox.Text += "\r\n\r\nIf the SmartInspect Console is not " + 
				"running, please start the SmartInspect Console and restart " + 
				"this example application";
		}

		private void MainForm_Load(object sender, System.EventArgs e)
		{
			SiAuto.Si.Error += new Gurock.SmartInspect.ErrorEventHandler(HandleError);
			SiAuto.Si.Enabled = true;

			try {
				this.pictureBox.Image = new Bitmap(
						@"..\..\common\SmartInspect.bmp"
					);
			} catch {}
		}

		private void closeButton_Click(object sender, System.EventArgs e)
		{
			Close();
		}

		private void messageButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LogMessage(messageTextBox.Text);
		}

		private void warningButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LogWarning(warningTextBox.Text);
		}

		private void errorButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LogError(errorTextBox.Text);
		}

		private void enterMethodButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.EnterMethod(enterMethodTextBox.Text);
		}

		private void leaveMethodButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LeaveMethod(leaveMethodTextBox.Text);
		}

		private void separatorButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LogSeparator();
		}

		private void addCheckpointButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.AddCheckpoint();
		}

		private void resetCheckpointButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.ResetCheckpoint();
		}

		private void exceptionButton_Click(object sender, System.EventArgs e)
		{
			try {
				int n = 0;
				n = 1 / n;
			} catch (Exception ex) {
				SiAuto.Main.LogException(ex);
			}
		}

		private void stringLogButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LogString("String", stringTextBox.Text);
		}

		private void stringWatchButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.WatchString("String", stringTextBox.Text);
		}

		private void charLogButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LogChar("Char", charTextBox.Text[0]);
		}

		private void charWatchButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.WatchChar("Char", charTextBox.Text[0]);
		}

		private void integerLogButton_Click(object sender, System.EventArgs e)
		{
			try {
				SiAuto.Main.LogInt(
						"Integer", Int32.Parse(integerTextBox.Text)
					);
			} catch (Exception ex) {
				MessageBox.Show(
						ex.Message, "Error", MessageBoxButtons.OK,
						MessageBoxIcon.Error
					);
			}
		}

		private void integerWatchButton_Click(object sender, System.EventArgs e)
		{
			try {
				SiAuto.Main.WatchInt(
						"Integer", Int32.Parse(integerTextBox.Text)
					);		
			} catch (Exception ex) {
				MessageBox.Show(
						ex.Message, "Error", MessageBoxButtons.OK,
						MessageBoxIcon.Error
					);
			}
		}

		private void doubleLogButton_Click(object sender, System.EventArgs e)
		{
			try {
				SiAuto.Main.LogDouble(
						"Double", Double.Parse(doubleTextBox.Text)
					);		
			} catch (Exception ex) {
				MessageBox.Show(
						ex.Message, "Error", MessageBoxButtons.OK,
						MessageBoxIcon.Error
					);
			}
		}

		private void doubleWatchButton_Click(object sender, System.EventArgs e)
		{
			try {
				SiAuto.Main.WatchDouble(
						"Double", Double.Parse(doubleTextBox.Text)
					);		
			} catch (Exception ex) {
				MessageBox.Show(
						ex.Message, "Error", MessageBoxButtons.OK,
						MessageBoxIcon.Error
					);
			}
		}

		private void sourceButton_Click(object sender, System.EventArgs e)
		{
			switch (sourceComboBox.SelectedIndex) {
				case 0: SiAuto.Main.LogSource("HTML", sourceTextBox.Text, SourceId.Html); break;
				case 1: SiAuto.Main.LogSource("JavaScript", sourceTextBox.Text, SourceId.JavaScript); break;
				case 2: SiAuto.Main.LogSource("VB Script", sourceTextBox.Text, SourceId.VbScript); break;
				case 3: SiAuto.Main.LogSource("Perl", sourceTextBox.Text, SourceId.Perl); break;
				case 4: SiAuto.Main.LogSource("SQL", sourceTextBox.Text, SourceId.Sql); break;
				case 5: SiAuto.Main.LogSource("INI File", sourceTextBox.Text, SourceId.Ini); break;
				case 6: SiAuto.Main.LogSource("Python", sourceTextBox.Text, SourceId.Python); break;
				case 7: SiAuto.Main.LogSource("Xml", sourceTextBox.Text, SourceId.Xml); break;
			}
		}

		private void objectButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LogObject("Form", this, true);
		}

		private void systemButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LogSystem();
		}

		private void pictureButton_Click(object sender, System.EventArgs e)
		{
			SiAuto.Main.LogBitmapFile(@"..\..\common\SmartInspect.bmp");
		}
	}
}
