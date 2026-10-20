<%@ Page Title="My bookings - CarBud Rentals" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="MyBookings.aspx.cs" Inherits="CarBud_Proto1.MyBookings" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <h1>My bookings</h1>

    <asp:Label ID="lblMessage" runat="server" CssClass="message message-ok" Visible="false" />

    <asp:Panel ID="pnlEmpty" runat="server" Visible="false" CssClass="empty">
        You have no bookings yet. <a href="Cars.aspx">Browse our cars</a>
    </asp:Panel>

    <asp:Repeater ID="rptBookings" runat="server" OnItemCommand="rptBookings_ItemCommand">
        <HeaderTemplate>
            <div class="table-wrap">
                <table class="bookings">
                    <thead>
                        <tr>
                            <th>No.</th>
                            <th>Car</th>
                            <th>Pick-up</th>
                            <th>Return</th>
                            <th>Days</th>
                            <th>Total</th>
                            <th>Status</th>
                            <th></th>
                        </tr>
                    </thead>
                    <tbody>
        </HeaderTemplate>
        <ItemTemplate>
                        <tr>
                            <td>#<%#: Eval("BookingID") %></td>
                            <td><%#: Eval("Make") %> <%#: Eval("Model") %></td>
                            <td><%#: Eval("StartDate", "{0:d MMM yyyy}") %></td>
                            <td><%#: Eval("EndDate", "{0:d MMM yyyy}") %></td>
                            <td><%#: Eval("Days") %></td>
                            <td><%#: Eval("TotalPrice") %> kr</td>
                            <td><span class='status status-<%#: Eval("BookingStatus").ToString().ToLower() %>'><%#: Eval("BookingStatus") %></span></td>
                            <td>
                                <asp:Button ID="btnCancel" runat="server" Text="Cancel" CssClass="btn btn-small btn-outline"
                                    CommandName="CancelBooking" CommandArgument='<%# Eval("BookingID") %>'
                                    Visible='<%# CanCancel(Container.DataItem) %>'
                                    OnClientClick="return confirm('Cancel this booking?');" />
                            </td>
                        </tr>
        </ItemTemplate>
        <FooterTemplate>
                    </tbody>
                </table>
            </div>
        </FooterTemplate>
    </asp:Repeater>
</asp:Content>
