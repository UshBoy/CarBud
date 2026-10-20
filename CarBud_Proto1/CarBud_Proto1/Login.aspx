<%@ Page Title="Log in - CarBud Rentals" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Login.aspx.cs" Inherits="CarBud_Proto1.Login" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <div class="form-card">
        <h1>Log in</h1>

        <asp:Label ID="lblMessage" runat="server" CssClass="message message-error" Visible="false" />

        <div class="field">
            <asp:Label ID="lblEmail" runat="server" AssociatedControlID="txtEmail" Text="Email" />
            <asp:TextBox ID="txtEmail" runat="server" TextMode="Email" MaxLength="150" />
            <asp:RequiredFieldValidator ID="rfvEmail" runat="server" ControlToValidate="txtEmail"
                ErrorMessage="Please enter your email." Display="Dynamic" CssClass="error" />
        </div>

        <div class="field">
            <asp:Label ID="lblPassword" runat="server" AssociatedControlID="txtPassword" Text="Password" />
            <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" />
            <asp:RequiredFieldValidator ID="rfvPassword" runat="server" ControlToValidate="txtPassword"
                ErrorMessage="Please enter your password." Display="Dynamic" CssClass="error" />
        </div>

        <asp:Button ID="btnLogin" runat="server" Text="Log in" CssClass="btn btn-full" OnClick="btnLogin_Click" />

        <p class="form-foot">New here? <asp:HyperLink ID="lnkToRegister" runat="server" NavigateUrl="Register.aspx" Text="Create an account" /></p>
    </div>
</asp:Content>
