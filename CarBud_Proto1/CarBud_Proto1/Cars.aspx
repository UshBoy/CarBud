<%@ Page Title="Cars - CarBud Rentals" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Cars.aspx.cs" Inherits="CarBud_Proto1.Cars" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <h1>Our cars</h1>

    <div class="filters">
        <div class="field">
            <asp:Label ID="lblType" runat="server" AssociatedControlID="ddlType" Text="Type" />
            <asp:DropDownList ID="ddlType" runat="server" />
        </div>
        <div class="field">
            <asp:Label ID="lblPrice" runat="server" AssociatedControlID="ddlPrice" Text="Price per day" />
            <asp:DropDownList ID="ddlPrice" runat="server">
                <asp:ListItem Value="" Text="Any price" />
                <asp:ListItem Value="400" Text="Up to 400 kr" />
                <asp:ListItem Value="700" Text="Up to 700 kr" />
                <asp:ListItem Value="1000" Text="Up to 1000 kr" />
            </asp:DropDownList>
        </div>
        <div class="field">
            <asp:Label ID="lblSeats" runat="server" AssociatedControlID="ddlSeats" Text="Seats" />
            <asp:DropDownList ID="ddlSeats" runat="server">
                <asp:ListItem Value="" Text="Any number" />
                <asp:ListItem Value="4" Text="4 or more" />
                <asp:ListItem Value="5" Text="5 or more" />
                <asp:ListItem Value="7" Text="7 or more" />
            </asp:DropDownList>
        </div>
        <asp:Button ID="btnFilter" runat="server" Text="Show cars" CssClass="btn" OnClick="btnFilter_Click" />
    </div>

    <p class="muted"><asp:Literal ID="litCount" runat="server" /></p>

    <div class="car-grid">
        <asp:Repeater ID="rptCars" runat="server">
            <ItemTemplate>
                <div class="car-card">
                    <div class="car-type"><%#: Eval("CarType") %></div>
                    <h3><%#: Eval("Make") %> <%#: Eval("Model") %></h3>
                    <ul class="specs">
                        <li><%#: Eval("Seats") %> seats</li>
                        <li><%#: Eval("BootLitres") %> L boot</li>
                        <li><%#: Eval("FuelType") %></li>
                    </ul>
                    <div class="car-foot">
                        <span class="price"><%#: Eval("PricePerDay") %> kr <small>/ day</small></span>
                        <a class="btn btn-small" href='CarDetails.aspx?id=<%# Eval("CarID") %>'>View &amp; book</a>
                    </div>
                </div>
            </ItemTemplate>
        </asp:Repeater>
    </div>

    <asp:Panel ID="pnlEmpty" runat="server" Visible="false" CssClass="empty">
        No cars match these filters. Try a higher price or fewer seats.
    </asp:Panel>
</asp:Content>
