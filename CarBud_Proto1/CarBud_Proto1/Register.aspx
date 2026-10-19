<%@ Page Title="Sign up - CarBud Rentals" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Register.aspx.cs" Inherits="CarBud_Proto1.Register" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="form-card">
        <h1>Create your account</h1>
        <p class="muted">You need an account to book a car.</p>

        <asp:Label ID="lblMessage" runat="server" CssClass="message message-error" Visible="false" />

        <div class="field">
            <asp:Label ID="lblName" runat="server" AssociatedControlID="txtName" Text="Full name" />
            <asp:TextBox ID="txtName" runat="server" MaxLength="100" />
            <asp:RequiredFieldValidator ID="rfvName" runat="server" ControlToValidate="txtName"
                ErrorMessage="Please enter your name." Display="Dynamic" CssClass="error" />
        </div>

        <div class="field">
            <asp:Label ID="lblEmail" runat="server" AssociatedControlID="txtEmail" Text="Email" />
            <asp:TextBox ID="txtEmail" runat="server" TextMode="Email" MaxLength="150" />
            <asp:RequiredFieldValidator ID="rfvEmail" runat="server" ControlToValidate="txtEmail"
                ErrorMessage="Please enter your email." Display="Dynamic" CssClass="error" />
            <asp:RegularExpressionValidator ID="revEmail" runat="server" ControlToValidate="txtEmail"
                ValidationExpression="^[^@\s]+@[^@\s]+\.[^@\s]+$"
                ErrorMessage="Please enter a valid email address." Display="Dynamic" CssClass="error" />
        </div>

        <div class="field">
            <asp:Label ID="lblPassword" runat="server" AssociatedControlID="txtPassword" Text="Password (at least 8 characters)" />
            <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" />
            <asp:RequiredFieldValidator ID="rfvPassword" runat="server" ControlToValidate="txtPassword"
                ErrorMessage="Please choose a password." Display="Dynamic" CssClass="error" />
            <asp:RegularExpressionValidator ID="revPassword" runat="server" ControlToValidate="txtPassword"
                ValidationExpression="^.{8,}$"
                ErrorMessage="Your password needs at least 8 characters." Display="Dynamic" CssClass="error" />
        </div>

        <div class="field">
            <asp:Label ID="lblConfirm" runat="server" AssociatedControlID="txtConfirm" Text="Repeat password" />
            <asp:TextBox ID="txtConfirm" runat="server" TextMode="Password" />
            <asp:CompareValidator ID="cvConfirm" runat="server" ControlToValidate="txtConfirm" ControlToCompare="txtPassword"
                ErrorMessage="The two passwords are not the same." Display="Dynamic" CssClass="error" />
        </div>

        <asp:Button ID="btnRegister" runat="server" Text="Create account" CssClass="btn btn-full" OnClick="btnRegister_Click" />

        <p class="form-foot">Already have an account? <a href="Login.aspx">Log in</a></p>
    </div>
</asp:Content>
