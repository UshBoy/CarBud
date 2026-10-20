<%@ Page Title="Car details - CarBud Rentals" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="CarDetails.aspx.cs" Inherits="CarBud_Proto1.CarDetails" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <p><a href="Cars.aspx">&larr; Back to all cars</a></p>

    <asp:Panel ID="pnlNotFound" runat="server" Visible="false" CssClass="empty">
        Sorry, we couldn't find that car. <a href="Cars.aspx">See all cars</a>
    </asp:Panel>

    <asp:Panel ID="pnlCar" runat="server" CssClass="detail">
        <div class="detail-info">
            <div class="car-type"><asp:Literal ID="litType" runat="server" /></div>
            <h1><asp:Literal ID="litTitle" runat="server" /></h1>
            <p class="price price-big"><asp:Literal ID="litPrice" runat="server" /> kr <small>/ day</small></p>
            <dl class="spec-list">
                <dt>Seats</dt>
                <dd><asp:Literal ID="litSeats" runat="server" /></dd>
                <dt>Boot space</dt>
                <dd><asp:Literal ID="litBoot" runat="server" /> litres</dd>
                <dt>Fuel</dt>
                <dd><asp:Literal ID="litFuel" runat="server" /></dd>
                <dt>Comfort</dt>
                <dd><asp:Literal ID="litComfort" runat="server" /> out of 5</dd>
            </dl>
        </div>

        <div class="detail-book">
            <h2>Book this car</h2>

            <%-- Shown when nobody is logged in --%>
            <asp:Panel ID="pnlLoginFirst" runat="server">
                <p class="muted">Please log in to book this car.</p>
                <asp:HyperLink ID="lnkLogin" runat="server" CssClass="btn btn-full" Text="Log in to book" />
                <p class="form-foot">No account yet? <asp:HyperLink ID="lnkRegister" runat="server" Text="Sign up" /></p>
            </asp:Panel>

            <%-- Shown when a customer is logged in --%>
            <asp:Panel ID="pnlBookForm" runat="server">
                <asp:Label ID="lblBookMessage" runat="server" CssClass="message message-error" Visible="false" />

                <div class="field">
                    <asp:Label ID="lblStart" runat="server" AssociatedControlID="txtStart" Text="Pick-up date" />
                    <asp:TextBox ID="txtStart" runat="server" TextMode="Date" ClientIDMode="Static" />
                    <asp:RequiredFieldValidator ID="rfvStart" runat="server" ControlToValidate="txtStart"
                        ErrorMessage="Please choose a pick-up date." Display="Dynamic" CssClass="error" />
                </div>

                <div class="field">
                    <asp:Label ID="lblEnd" runat="server" AssociatedControlID="txtEnd" Text="Return date" />
                    <asp:TextBox ID="txtEnd" runat="server" TextMode="Date" ClientIDMode="Static" />
                    <asp:RequiredFieldValidator ID="rfvEnd" runat="server" ControlToValidate="txtEnd"
                        ErrorMessage="Please choose a return date." Display="Dynamic" CssClass="error" />
                </div>

                <asp:HiddenField ID="hfPrice" runat="server" ClientIDMode="Static" />
                <p id="estimate" class="estimate"></p>

                <asp:Button ID="btnBook" runat="server" Text="Book this car" CssClass="btn btn-full" OnClick="btnBook_Click" />
            </asp:Panel>
        </div>
    </asp:Panel>

    <script>
        // Shows the price while the customer picks dates. The real price is always calculated again by the database.
        (function () {
            var start = document.getElementById('txtStart');
            var end = document.getElementById('txtEnd');
            var price = document.getElementById('hfPrice');
            var output = document.getElementById('estimate');
            if (!start || !end || !price || !output) { return; }

            function update() {
                var days = Math.round((new Date(end.value) - new Date(start.value)) / 86400000);
                if (start.value && end.value && days > 0) {
                    output.textContent = days + (days === 1 ? ' day' : ' days') + ' x ' + price.value + ' kr = ' + (days * Number(price.value)) + ' kr';
                } else {
                    output.textContent = '';
                }
            }

            start.addEventListener('change', update);
            end.addEventListener('change', update);
            update();
        })();
    </script>
</asp:Content>
